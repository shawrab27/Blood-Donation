from rest_framework import views, status
from rest_framework.response import Response
from rest_framework.permissions import IsAdminUser
from rest_framework.pagination import PageNumberPagination
from api.models import AdminAction

class StandardResultsSetPagination(PageNumberPagination):
    page_size = 50
    page_size_query_param = 'page_size'
    max_page_size = 100

class AdminAuditLogAPIView(views.APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        queryset = AdminAction.objects.select_related('admin_user').all().order_by('-timestamp')

        # Filters
        admin_id = request.query_params.get('admin_user_id')
        action_type = request.query_params.get('action_type')
        date_from = request.query_params.get('from')
        date_to = request.query_params.get('to')

        if admin_id:
            queryset = queryset.filter(admin_user_id=admin_id)
        if action_type:
            queryset = queryset.filter(action_type__icontains=action_type)
        if date_from:
            queryset = queryset.filter(timestamp__gte=date_from)
        if date_to:
            queryset = queryset.filter(timestamp__lte=date_to)

        # Pagination
        paginator = StandardResultsSetPagination()
        page = paginator.paginate_queryset(queryset, request, view=self)

        data = []
        iterable = page if page is not None else queryset
        for action in iterable:
            data.append({
                'id': action.id,
                'admin_id': action.admin_user.id,
                'admin_name': f"{action.admin_user.first_name} {action.admin_user.last_name}".strip() or action.admin_user.username,
                'action_type': action.action_type,
                'target_id': action.target_id,
                'timestamp': action.timestamp,
                'notes': action.notes
            })

        if page is not None:
            return paginator.get_paginated_response(data)
        
        return Response(data)
