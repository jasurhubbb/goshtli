"""Chat business logic — get_or_create a 1:1 conversation between two users (handles the ordered-pair invariant)."""
from .models import Conversation


def get_or_create_for(user_a, user_b) -> Conversation:
    """Return the single Conversation row for this pair, creating it if missing.

    Enforces user_a.id < user_b.id at insert so the unique-pair constraint stays satisfied regardless of caller order.
    """
    if user_a.id == user_b.id: raise ValueError("Can't start a chat with yourself")
    lo, hi = (user_a, user_b) if user_a.id < user_b.id else (user_b, user_a)
    conv, _ = Conversation.objects.get_or_create(user_a=lo, user_b=hi)
    return conv
