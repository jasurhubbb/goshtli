"""Notification views — list own, mark-read (single + bulk), unread count for the bell badge."""
from drf_spectacular.utils import extend_schema, OpenApiParameter, OpenApiTypes
from rest_framework import generics, permissions, status
from rest_framework.exceptions import NotFound
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Notification
from .serializers import NotificationSerializer


class NotificationListView(generics.ListAPIView):
    """GET /api/v1/notifications/ — current user's notifications, newest first; supports ?is_read= filter."""
    serializer_class = NotificationSerializer
    permission_classes = (permissions.IsAuthenticated,)
    filterset_fields = ("is_read", "kind")

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False): return Notification.objects.none()
        return Notification.objects.filter(user=self.request.user)


@extend_schema(request=None, responses={200: NotificationSerializer},
               parameters=[OpenApiParameter("pk", OpenApiTypes.INT, OpenApiParameter.PATH)])
class NotificationMarkReadView(APIView):
    """POST /api/v1/notifications/{id}/read/ — flip is_read=True on a single notification owned by the caller."""
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, pk):
        try: n = Notification.objects.get(pk=pk, user=request.user)
        except Notification.DoesNotExist: raise NotFound()
        if not n.is_read:
            n.is_read = True; n.save(update_fields=("is_read", "updated_at"))
        return Response(NotificationSerializer(n).data)


@extend_schema(request=None, responses={204: None})
class NotificationMarkAllReadView(APIView):
    """POST /api/v1/notifications/read-all/ — bulk-flip every unread notification for this user. Cheap UPDATE, no row reads."""
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request):
        Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
        return Response(status=status.HTTP_204_NO_CONTENT)


@extend_schema(responses={200: {"type": "object", "properties": {"unread": {"type": "integer"}}}})
class NotificationUnreadCountView(APIView):
    """GET /api/v1/notifications/unread-count/ — drives the bell-icon badge in the mobile AppBar. Indexed; cheap."""
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request):
        return Response({"unread": Notification.objects.filter(user=request.user, is_read=False).count()})
