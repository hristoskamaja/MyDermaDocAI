from django.urls import path, register_converter

from . import views


class IsoDateConverter:
    regex = r"\d{4}-\d{2}-\d{2}"

    def to_python(self, value):
        from datetime import date
        try:
            return date.fromisoformat(value)
        except ValueError:
            raise ValueError("invalid date")

    def to_url(self, value):
        return value.isoformat()


register_converter(IsoDateConverter, "isodate")

urlpatterns = [
    path("logs/", views.logs_collection, name="tracking_logs"),
    path("logs/<isodate:day>/", views.log_detail, name="tracking_log_detail"),
    path("logs/<isodate:day>/photo/", views.log_photo, name="tracking_log_photo"),

    path("products/", views.products_collection, name="tracking_products"),
    path("products/<int:id>/", views.product_detail, name="tracking_product_detail"),

    path("today/", views.today_status, name="tracking_today"),
    path("week/", views.week_view, name="tracking_week"),
    path("timeline/", views.timeline_view, name="tracking_timeline"),
    path("insights/", views.insights_view, name="tracking_insights"),
    path("correlation/", views.correlation_view, name="tracking_correlation"),
    path("weekly-report/", views.weekly_report_view, name="tracking_weekly_report"),
    path("ask/", views.ask_view, name="tracking_ask"),
    path("ask/suggestions/", views.suggested_questions, name="tracking_ask_suggestions"),
    path("reminders/", views.reminders_view, name="tracking_reminders"),

    path("scans/", views.scans_collection, name="tracking_scans"),
    path("scans/<int:id>/", views.scan_delete, name="tracking_scan_delete"),
    path("scans/<int:analysis_id>/save/", views.scan_save, name="tracking_scan_save"),

    path("data/", views.delete_all_tracking_data, name="tracking_delete_all"),
]
