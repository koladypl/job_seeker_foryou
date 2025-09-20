import re
import traceback
from datetime import datetime
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import requests

PL_CURRENCY = 'PLN'

# ---------------- Funkcje pomocnicze ---------------- #

def parse_salary(text):
    if not text:
        return None, None, PL_CURRENCY
    t = text.replace('\u00a0', ' ').replace(',', '.')
    nums = re.findall(r'(\d+(?:\.\d+)*)', t)
    vals = []
    for n in nums:
        try:
            val = float(n)
            if val < 1000:
                val *= 1000
            vals.append(int(val))
        except:
            pass
    if not vals:
        return None, None, PL_CURRENCY
    if len(vals) == 1:
        return vals[0], vals[0], PL_CURRENCY
    return min(vals), max(vals), PL_CURRENCY

def clean_list(soup_list):
    return [' '.join(li.get_text(' ', strip=True).split()) for li in soup_list if li.get_text(strip=True)]

def extract_address_and_location(block):
    address = ''
    city = ''
    region = ''

    addr_tag = block.find('address')
    if addr_tag:
        address = ' '.join(addr_tag.get_text(' ', strip=True).split())

    text = ' '.join(block.get_text(' ', strip=True).split())
    city_match = re.search(
        r'\b(Szczecin|Warszawa|Gdańsk|Poznań|Wrocław|Kraków|Łódź|Katowice|Białystok|Rzeszów|Lublin|Gdynia|Sopot)\b',
        text, re.I
    )
    if city_match:
        city = city_match.group(0).capitalize()

    region_match = re.search(
        r'(dolnośląskie|kujawsko-pomorskie|lubelskie|lubuskie|łódzkie|małopolskie|mazowieckie|opolskie|podkarpackie|podlaskie|pomorskie|śląskie|świętokrzyskie|warmińsko-mazurskie|wielkopolskie|zachodniopomorskie)',
        text, re.I
    )
    if region_match:
        r = region_match.group(0).lower()
        region = r[0].upper() + r[1:]
    return address, city, region

def extract_contracts(text):
    types = []
    for key in ['umowa o pracę', 'umowa zlecenie', 'umowa o dzieło', 'B2B', 'kontrakt B2B']:
        if key.lower() in text.lower():
            types.append('B2B' if key.lower() == 'kontrakt b2b' else key)
    return list(dict.fromkeys(types))

def parse_posted_at(text):
    months = {
        'stycznia':1, 'lutego':2, 'marca':3, 'kwietnia':4, 'maja':5, 'czerwca':6,
        'lipca':7, 'sierpnia':8, 'września':9, 'października':10, 'listopada':11, 'grudnia':12
    }
    m = re.search(r'(\d{1,2})\s+([a-ząćęłńóśźż]+)\s+(\d{4})', text.lower())
    if m:
        d, mon, y = int(m.group(1)), months.get(m.group(2), 1), int(m.group(3))
        return datetime(y, mon, d).date()
    try:
        return datetime.fromisoformat(text).date()
    except:
        return None

def geocode_address(address):
    try:
        if not address or not address.strip():
            return None, None
        resp = requests.get(
            "https://nominatim.openstreetmap.org/search",
            params={"q": address, "format": "json", "limit": 1},
            headers={"User-Agent": "JobScraper/1.0"},
            timeout=10
        )
        data = resp.json()
        if data:
            lat = float(data[0]['lat'])
            lon = float(data[0]['lon'])
            print(f"🗺️ Geocoded: {address} -> {lat}, {lon}")
            return lat, lon
        print(f"⚠️ Geocode brak wyników dla: {address}")
    except Exception as e:
        print(f"❌ Geocode error dla: {address} :: {e}")
    return None, None

def extract_company(soup):
    """
    Próbujemy wielu selektorów, pod różne portale.
    Odfiltrowujemy generyczne teksty typu 'O firmie'.
    """
    candidates = [
        '[data-test="text-company-name"]',
        'a[data-test="link-company-name"]',
        '.company',
        '.posting-company',
        '.employer',
        '.job-header__company',
        '.job-company',
        'a[href*="company"]',
        'a[aria-label*="Firma"]',
    ]
    for sel in candidates:
        el = soup.select_one(sel)
        if el:
            txt = el.get_text(strip=True)
            if txt and txt.lower() not in ['o firmie', 'informacje o firmie']:
                return txt
    return ''

def extract_salary_text(soup):
    text = soup.get_text(' ', strip=True)
    m = re.search(r'([\d\s.,]+-\s*[\d\s.,]+\s*zł.*?(brutto|netto)?|[\d\s.,]+\s*zł.*?(brutto|netto)?)', text, re.I)
    if m:
        return m.group(0).strip()
    el = soup.find(string=re.compile(r'\bzł\b')) or soup.find(string=re.compile(r'brutto|netto', re.I))
    if isinstance(el, str):
        return el.strip()
    if el:
        return el.get_text(' ', strip=True)
    return ''

# ---------------- Główna funkcja scrapera ---------------- #

def scrape_job(url, source_name='pracuj.pl'):
    driver = None
    try:
        chrome_options = Options()
        chrome_options.add_argument("--headless=new")
        chrome_options.add_argument("--disable-gpu")
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--window-size=1920,1080")
        chrome_options.add_argument("--disable-blink-features=AutomationControlled")

        driver = webdriver.Chrome(options=chrome_options)
        driver.get(url)

        WebDriverWait(driver, 15).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "h1"))
        )

        html = driver.page_source
        soup = BeautifulSoup(html, 'html.parser')

        # Zapis HTML do debugowania
        with open("debug_offer.html", "w", encoding="utf-8") as f:
            f.write(soup.prettify())

        # Tytuł
        title_el = soup.select_one('h1, h1.job-title, .job-title')
        title_text = title_el.get_text(strip=True) if title_el else ''

        # Firma
        company_text = extract_company(soup)
        if not company_text:
            print(f"⚠️ Nie znaleziono nazwy firmy dla: {url}")

        # Lokalizacja
        details_block = soup.select_one('.job-details, .details, .offer-details, .job-offer, main, body') or soup
        address, city, region = extract_address_and_location(details_block)
        remote = any(s in soup.get_text(' ', strip=True).lower() for s in ['praca zdalna', 'zdalna', 'remote'])

        # Wynagrodzenie
        salary_text = extract_salary_text(soup)
        s_min, s_max, currency = parse_salary(salary_text) if salary_text else (None, None, PL_CURRENCY)

        # Typ umowy, czas pracy
        full_text = soup.get_text(' ', strip=True)
        contract_types = extract_contracts(full_text)
        work_time = 'pełny etat' if 'pełny etat' in full_text.lower() else ''

        # Sekcje listowe
        duties = clean_list(soup.select('[data-test="section-responsibilities"] li'))
        requirements = clean_list(soup.select('[data-test="section-requirements"] li'))
        benefits = clean_list(soup.select('[data-test="section-benefits"] li'))

                # Data publikacji
        date_node = soup.find(string=re.compile(r'Opublikowano|Dodano|Published', re.I)) or soup.find('time')
        posted_at = None
        if date_node:
            txt = date_node if isinstance(date_node, str) else date_node.get_text(' ', strip=True)
            posted_at = parse_posted_at(txt)

        # Opis (krótki) + fallback
        description = ' '.join(
            p.get_text(' ', strip=True)
            for p in soup.select('article p, .description p, .job-description p')[:12]
        ).strip()

        if not description:
            parts = []
            if company_text:
                parts.append(f"Oferta w firmie {company_text}")
            if title_text:
                parts.append(f"na stanowisku {title_text}")
            loc_str = ', '.join([b for b in [city, region] if b])
            if loc_str:
                parts.append(f"({loc_str})")
            description = (' '.join(parts) + '.') if parts else "Oferta pracy. Szczegóły nie zostały podane w oryginalnej treści."

        # Geolokalizacja – użyj nazwy firmy tylko jeśli nie jest generyczna
        full_address_parts = [address, city, region]
        if company_text and company_text.lower() not in ['o firmie', 'informacje o firmie']:
            full_address_parts.insert(0, company_text)
        full_address = ', '.join([a for a in full_address_parts if a])
        lat, lon = geocode_address(full_address) if full_address else (None, None)

        # Zwracamy dane
        return dict(
            source_name=source_name,
            source_url=url,
            title=title_text,
            company=company_text,
            address=address,
            city=city,
            region=region,
            location=', '.join([b for b in [city, region] if b]),
            latitude=lat,
            longitude=lon,
            is_remote=remote,
            salary_text=salary_text,
            salary_min=s_min,
            salary_max=s_max,
            currency=currency or PL_CURRENCY,
            contract_types=contract_types,
            work_time=work_time,
            posted_at=posted_at,
            duties=duties,
            requirements=requirements,
            benefits=benefits,
            description=description,
        )

    except Exception as e:
        print("❌ Błąd scrapowania:", e)
        traceback.print_exc()
        return {}
    finally:
        if driver:
            try:
                driver.quit()
            except Exception:
                pass
