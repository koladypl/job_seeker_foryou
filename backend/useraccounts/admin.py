from django.contrib import admin
from .models import DeviceToken

@admin.register(DeviceToken)
class DeviceTokenAdmin(admin.ModelAdmin):
    list_display = ('user', 'platform', 'token', 'created_at')
    search_fields = ('user__username', 'platform', 'token')
