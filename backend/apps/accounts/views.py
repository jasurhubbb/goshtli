"""Auth views — registration, /me (GET/PATCH/DELETE), and any extra account-level actions.

v2 additions:
  • DELETE /auth/me/ — Play Store policy requires apps with accounts to let users delete their own account.
    Hard delete via cascade. Refuses if the user owns listings that have orders (would orphan the audit trail).
"""
from django.db.models import ProtectedError
from drf_spectacular.utils import extend_schema
from rest_framework import generics, permissions, status
from rest_framework.response import Response

from .models import User
from .serializers import RegisterSerializer, UserSerializer


class RegisterView(generics.CreateAPIView):
    """POST /api/v1/auth/register/ — public; creates a SUPPLIER or BUYER. Admins are created via createsuperuser only."""
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = (permissions.AllowAny,)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)


@extend_schema(methods=["DELETE"], responses={204: None, 409: None},
               description="Permanently delete the authenticated user's account. Refuses if they have listings "
                           "with attached orders — those need to be cancelled/completed first.")
class MeView(generics.RetrieveUpdateDestroyAPIView):
    """GET/PATCH/DELETE /api/v1/auth/me/ — current user's record. PATCH locks email/role per the serializer."""
    serializer_class = UserSerializer
    permission_classes = (permissions.IsAuthenticated,)
    # PUT excluded — full-replace doesn't make sense for /me; PATCH is the intended write path
    http_method_names = ("get", "patch", "delete", "head", "options")

    def get_object(self): return self.request.user

    def destroy(self, request, *args, **kwargs):
        # Cascade deletes the user + their profiles + their buyer-orders. Listings with order rows are PROTECTed,
        # which raises ProtectedError — we translate to 409 so the UI can show "cancel your active orders first".
        try:
            self.get_object().delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except ProtectedError:
            return Response({"detail": "Cannot delete account — you have listings with active orders. "
                                       "Cancel or complete them first."},
                            status=status.HTTP_409_CONFLICT)
