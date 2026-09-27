from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from django.db.models import Case, When, Value, IntegerField
from .models import Institution, Upazila

@api_view(['GET'])
@permission_classes([AllowAny])
def institution_search(request):
    q = request.GET.get('q', '').strip()
    if not q:
        return Response([])

    results = Institution.objects.filter(name__icontains=q).annotate(
        starts_with=Case(
            When(name__istartswith=q, then=Value(1)),
            default=Value(0),
            output_field=IntegerField()
        )
    ).order_by('-starts_with', 'name')[:10]

    data = [
        {
            'id': inst.id,
            'name': inst.name,
            'institution_type': inst.institution_type,
            'eiin': inst.eiin
        }
        for inst in results
    ]
    return Response(data)

@api_view(['GET'])
@permission_classes([AllowAny])
def upazila_search(request):
    q = request.GET.get('q', '').strip()
    if not q:
        return Response([])

    results = Upazila.objects.filter(name__icontains=q).annotate(
        starts_with=Case(
            When(name__istartswith=q, then=Value(1)),
            default=Value(0),
            output_field=IntegerField()
        )
    ).order_by('-starts_with', 'name')[:10]

    data = [
        {
            'id': up.id,
            'name': up.name,
            'district_id': up.district_id
        }
        for up in results
    ]
    return Response(data)
