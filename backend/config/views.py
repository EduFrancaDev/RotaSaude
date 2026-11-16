import logging

from django.db import connection
from django.db.utils import Error as DatabaseError
from rest_framework.decorators import api_view
from rest_framework.response import Response

logger = logging.getLogger(__name__)


@api_view(["GET"])
def health(request):
    """Verifica se a API está de pé e se o banco responde."""
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
    except DatabaseError:
        logger.exception("Health check: falha ao consultar o banco de dados")
        return Response({"status": "error", "database": "unavailable"}, status=503)
    return Response({"status": "ok", "database": "ok"})
