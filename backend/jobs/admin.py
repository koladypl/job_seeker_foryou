from django.contrib import admin
from .models import Job

@admin.register(Job)
class JobAdmin(admin.ModelAdmin):
    list_display = ('title', 'company', 'city', 'region', 'is_remote', 'posted_at', 'updated_at')
    search_fields = ('title', 'company', 'city', 'region')
    list_filter = ('is_remote', 'region', 'posted_at')
    ordering = ('-created_at',)

    # To pozwala zaznaczać wiele rekordów i usuwać je jednym kliknięciem
    actions = ['delete_selected']
