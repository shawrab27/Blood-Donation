@api_view(['POST'])
@permission_classes([IsAuthenticated])
def emergency_request_all_view(request):
    return Response({'message': 'No eligible donors found.', 'notified': 0}, status=status.HTTP_200_OK)
