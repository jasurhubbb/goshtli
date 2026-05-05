"""Auth views — public registration, plus an authenticated /users/me endpoint for fetching the current user's profile."""
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from .models import User
from .serializers import RegisterSerializer, UserSerializer


class RegisterView(generics.CreateAPIView):
    """POST /api/v1/auth/register/ — public; creates a SUPPLIER or BUYER. Admins are created via createsuperuser only."""
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = (permissions.AllowAny,)  # registration must be reachable without auth

    def create(self, request, *args, **kwargs):
        # Run validation + create via the serializer, then return the safe UserSerializer shape (no password echoed)
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)


class MeView(generics.RetrieveUpdateAPIView):
    """GET/PATCH /api/v1/auth/me/ — returns or updates the authenticated user's own profile (full_name, phone)."""
    serializer_class = UserSerializer
    permission_classes = (permissions.IsAuthenticated,)
    # Restrict patchable fields — email/role/is_active changes require admin or a separate flow, not /me
    http_method_names = ("get", "patch", "head", "options")

    def get_object(self): return self.request.user  # always operate on the caller, never on arbitrary user IDs
