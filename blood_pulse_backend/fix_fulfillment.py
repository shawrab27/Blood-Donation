# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
content = open('api/views_bloodhub.py').read()
old = '''    if new_status == 'DONATED':
        if not (is_donor or is_requester):
            return Response({'error': 'Unauthorized.'}, status=status.HTTP_403_FORBIDDEN)

        acceptance.status = 'DONATED'
        acceptance.completed_at = now
        acceptance.save(update_fields=['status', 'completed_at'])

        # Fulfill request
        blood_req = acceptance.request
        blood_req.status = 'FULFILLED'
        blood_req.is_active = False
        blood_req.save(update_fields=['status', 'is_active'])

        # Update donor stats
        donor = acceptance.donor
        donor.fulfilled_count = (donor.fulfilled_count or 0) + 1
        donor.total_bags_donated = (donor.total_bags_donated or 0) + (blood_req.units_needed or 1)
        donor.last_donation_date = now.date()
        donor.is_available = False
        donor.save(update_fields=['fulfilled_count', 'total_bags_donated', 'last_donation_date', 'is_available'])

        # Record donation history
        from api.models import DonationHistory
        DonationHistory.objects.create('''

new = '''    if new_status == 'DONATED':
        acceptance.status = 'DONATED'
        acceptance.save(update_fields=['status'])
        return Response({'status': 'DONATED', 'message': 'Pending requester confirmation.'})

    elif new_status == 'CONFIRMED':
        if not is_requester: return Response({'error': 'Unauthorized.'}, status=403)
        acceptance.status = 'CONFIRMED'
        acceptance.completed_at = now
        acceptance.save(update_fields=['status', 'completed_at'])
        blood_req = acceptance.request
        blood_req.status = 'FULFILLED'
        blood_req.is_active = False
        blood_req.save(update_fields=['status', 'is_active'])
        donor = acceptance.donor
        donor.fulfilled_count = (donor.fulfilled_count or 0) + 1
        donor.total_bags_donated = (donor.total_bags_donated or 0) + (blood_req.units_needed or 1)
        donor.last_donation_date = now.date()
        donor.is_available = False
        donor.save(update_fields=['fulfilled_count', 'total_bags_donated', 'last_donation_date', 'is_available'])
        from api.models import DonationHistory
        DonationHistory.objects.create('''

content = content.replace(old, new)
content = content.replace("['ON_THE_WAY', 'ARRIVED', 'DONATED', 'CANCELLED']", "['ON_THE_WAY', 'ARRIVED', 'DONATED', 'CANCELLED', 'CONFIRMED']")
open('api/views_bloodhub.py', 'w').write(content)
