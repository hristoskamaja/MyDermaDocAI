from django.urls import path

from . import views

urlpatterns = [
    path("scan-skin/", views.scan_skin, name="scan_skin"),
    path("my-analyses/", views.my_analyses, name="my_analyses"),
    path("<int:id>/", views.analysis_detail, name="analysis_detail"),
    path("<int:id>/pdf/", views.analysis_pdf, name="analysis_pdf"),
    path("<int:id>/chat/", views.analysis_chat, name="analysis_chat"),
    path("", views.list_analyses, name="list_analyses"),
]
