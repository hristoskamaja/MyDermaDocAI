from django.db.models.signals import post_delete
from django.dispatch import receiver

from .models import DailyLog


@receiver(post_delete, sender=DailyLog)
def delete_photo_file(sender, instance, **kwargs):
    """Runs for single deletes AND queryset/cascade deletes (user, delete-all)."""
    if instance.photo:
        instance.photo.delete(save=False)
