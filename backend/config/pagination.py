from rest_framework.pagination import PageNumberPagination


class StandardPagination(PageNumberPagination):
    """Paginação por página: `?page=N&page_size=M`.

    Resposta: `{"count": int, "next": url|null, "previous": url|null, "results": [...]}`.
    """

    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100
