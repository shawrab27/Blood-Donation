import sys

with open('blood_pulse_backend/api/services/journeys.py', 'r') as f:
    text = f.read()

new_func = '''
def auto_manage_deferrals():
    """
    Enforces the 90-day cooldown policy. 
    Defers any available donor whose last_donation_date > cutoff (i.e. < 90 days ago).
    Re-enables any unavailable (and unsuspended) donor whose last_donation_date <= cutoff.
    Returns (deferred_count, reenabled_count).
    """
    now = timezone.now().date()
    cutoff = now - timedelta(days=90)

    from api.models import DonorProfile
    
    # Needs to be deferred (donated less than 90 days ago)
    newly_deferred = DonorProfile.objects.filter(
        is_available=True,
        last_donation_date__gt=cutoff
    ).update(is_available=False)

    # Needs to be re-enabled (donated 90+ days ago)
    newly_available = DonorProfile.objects.filter(
        is_available=False,
        is_suspended=False,
        last_donation_date__lte=cutoff
    ).update(is_available=True)

    return newly_deferred, newly_available
'''

if 'auto_manage_deferrals' not in text:
    with open('blood_pulse_backend/api/services/journeys.py', 'a') as f:
        f.write(new_func)
    print('Added auto_manage_deferrals')
