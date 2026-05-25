"""Category routes — mounted at /api/v1/categories/ from config/urls.py. Lives inside apps.listings because
the MeatCategory model + admin are already in this app; promoting to its own app isn't worth the indirection
for two views."""
from django.urls import path
from .views import MeatCategoryDetailView, MeatCategoryListCreateView

urlpatterns = [
    path("", MeatCategoryListCreateView.as_view(), name="category-list"),
    path("<int:pk>/", MeatCategoryDetailView.as_view(), name="category-detail"),
]
