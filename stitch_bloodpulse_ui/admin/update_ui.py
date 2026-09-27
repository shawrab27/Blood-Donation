import re

with open('donor-management.html', 'r', encoding='utf-8') as f:
    html = f.read()

# Replace suspendDonor JS function
new_suspend_js = """
    async function suspendDonor(id, is_suspended) {
        const msg = is_suspended ? 'Un-suspend donor (restore availability)?' : 'Suspend donor (set unavailable)?';
        if (confirm(msg)) {
            try {
                const res = await fetch(`http://127.0.0.1:8000/api/admin/donors/${id}/suspend/`, { method: 'POST', headers: getHeaders() });
                if (res.ok) {
                    const data = await res.json();
                    showToast(data.status === 'suspended' ? 'Donor Suspended' : 'Donor Unsuspended');
                    fetchDonors();
                } else if (res.status === 401 || res.status === 403) {
                    window.location.href = 'admin-login.html';
                } else {
                    showToast('Action failed', true);
                }
            } catch (e) {
                console.error(e);
                showToast('Network error', true);
            }
        }
    }
"""
html = re.sub(r'function suspendDonor\(id\) \{.*?\}', new_suspend_js.strip(), html, flags=re.DOTALL)

# Update renderDonors to show status correctly and pass is_suspended
# Find: <span class="text-[11px] text-[#6B7280]">${item.is_available ? 'Available' : 'Unavailable'}</span>
# Replace with: <span class="text-[11px] text-[#6B7280]">${item.is_suspended ? 'Suspended' : (item.is_available ? 'Available' : 'Unavailable')}</span>
html = html.replace(
    "<span class=\"text-[11px] text-[#6B7280]\">${item.is_available ? 'Available' : 'Unavailable'}</span>",
    "<span class=\"text-[11px] text-[#6B7280]\">${item.is_suspended ? 'Suspended' : (item.is_available ? 'Available' : 'Unavailable')}</span>"
)

# Update the suspend button
old_button = """<button onclick="suspendDonor(${item.id})" class="p-1 rounded-full hover:bg-[#FAF0F0] text-[#594A4B] transition-colors" type="button" title="Suspend">
                        <span class="material-symbols-outlined text-[18px]">flip_camera_ios</span>
                    </button>"""
new_button = """<button onclick="suspendDonor(${item.id}, ${item.is_suspended})" class="p-1 rounded-full hover:bg-[#FAF0F0] text-[#594A4B] transition-colors" type="button" title="${item.is_suspended ? 'Unsuspend' : 'Suspend'}">
                        <span class="material-symbols-outlined text-[18px] ${item.is_suspended ? 'text-red-500' : ''}">flip_camera_ios</span>
                    </button>"""
html = html.replace(old_button, new_button)

with open('donor-management.html', 'w', encoding='utf-8') as f:
    f.write(html)
print("UI updated.")
