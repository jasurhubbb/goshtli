"""Notification views — list own, mark-read (single + bulk), unread count, register device for push."""
from drf_spectacular.utils import extend_schema, OpenApiParameter, OpenApiTypes
from rest_framework import generics, permissions, status
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import DeviceToken, Notification
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
    """POST /api/v1/notifications/read-all/ — bulk-flip every unread notification for this user. Cheap UPDATE."""
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


@extend_schema(request={"application/json": {"type": "object", "properties": {
                    "token": {"type": "string"}, "platform": {"type": "string", "enum": ["ANDROID", "IOS", "WEB"]}}}},
               responses={200: None, 201: None})
class RegisterDeviceView(APIView):
    """POST /api/v1/notifications/register-device/ — Flutter calls this after obtaining the FCM token.

    Re-binds an existing token to the calling user if it's already in the DB (handles account-switching on the same
    device — the new user inherits the token, the old user loses it). Idempotent on repeat calls.
    """
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request):
        token = (request.data.get("token") or "").strip()
        if not token: raise ValidationError({"token": "Required."})
        platform = (request.data.get("platform") or "ANDROID").upper()
        if platform not in {p for p, _ in DeviceToken.Platform.choices}:
            raise ValidationError({"platform": "Invalid platform."})
        # update_or_create on the unique token column — re-claiming a token from a previous user is the standard pattern
        _, created = DeviceToken.objects.update_or_create(
            token=token, defaults={"user": request.user, "platform": platform})
        return Response(status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)
