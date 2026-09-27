import re

with open('donor-management.html', 'r', encoding='utf-8') as f:
    html = f.read()

# 1. Strip hardcoded rows
html = re.sub(
    r'<tbody class="divide-y divide-\[#EBDCDC\]">.*?</tbody>',
    '<tbody class="divide-y divide-[#EBDCDC]" id="donor-table-body"></tbody>',
    html,
    flags=re.DOTALL
)

# 2. Add Toast notification container
toast_html = """
<!-- Notification Toast -->
<div class="fixed bottom-6 right-6 z-50 bg-[#2B2B2B] text-white px-md py-sm rounded-lg shadow-xl flex items-center gap-sm transform translate-y-20 opacity-0 transition-all duration-300 pointer-events-none" id="toast">
<span class="material-symbols-outlined text-[20px] text-red-300" id="toast-icon">check_circle</span>
<span class="font-body-sm text-body-sm" id="toast-message">Action executed successfully</span>
</div>
"""
if 'id="toast"' not in html:
    html = html.replace('</body>', toast_html + '\n</body>')

# 3. Dynamic modal adjustments
html = html.replace('Sarah Jenkins', '<span id="modal-donor-name"></span>')
html = html.replace('UID #D-8492', 'UID #D-<span id="modal-donor-uid"></span>')
html = html.replace('O- Negative', '<span id="modal-donor-bg"></span>')
html = html.replace('"ANON_DONOR_8492"', '"ANON_DONOR_<span id="modal-anon-uid"></span>"')
html = html.replace('12 donation records', '<span id="modal-donor-donations"></span> donation records')
html = html.replace('Their 12 donation records', 'Their <span id="modal-donor-donations-2"></span> donation records')
html = html.replace('12 Anonymized Transfusion Logs', '<span id="modal-donor-donations-3"></span> Anonymized Transfusion Logs')

# Add id to the erase confirm button and remove its alert onclick
html = re.sub(
    r'<button[^>]*onclick="alert\(\'Executing irreversible[^>]*>[^<]*<span[^>]*>[^<]*</span>[^<]*<span[^>]*>Execute Irreversible Erase</span></button>',
    '<button id="confirm-erase-btn" class="inline-flex items-center gap-2 px-6 py-2 rounded-full bg-[#C30121] text-white hover:bg-[#A1001B] transition-colors text-xs font-semibold shadow-sm" type="button"><span class="material-symbols-outlined text-[18px]">delete_forever</span><span>Execute Irreversible Erase</span></button>',
    html,
    flags=re.DOTALL
)

# 4. Javascript logic
js_logic = """
<script>
    function getHeaders() {
        const token = localStorage.getItem('access_token');
        return {
            'Content-Type': 'application/json',
            'Authorization': token ? `Bearer ${token}` : ''
        };
    }

    function showToast(message, isError = false) {
      const toast = document.getElementById('toast');
      const toastIcon = document.getElementById('toast-icon');
      
      document.getElementById('toast-message').innerText = message;
      
      if (isError) {
        toastIcon.innerText = 'error';
        toastIcon.classList.remove('text-red-300');
        toastIcon.classList.add('text-[#C30121]');
      } else {
        toastIcon.innerText = 'check_circle';
        toastIcon.classList.remove('text-[#C30121]');
        toastIcon.classList.add('text-red-300');
      }
  
      toast.classList.remove('translate-y-20', 'opacity-0');
      toast.classList.add('translate-y-0', 'opacity-100');
      setTimeout(() => {
        toast.classList.add('translate-y-20', 'opacity-0');
        toast.classList.remove('translate-y-0', 'opacity-100');
      }, 4000);
    }

    let currentEraseDonorId = null;

    function openEraseModal(id, name, uid, bg, donations) {
        currentEraseDonorId = id;
        document.querySelectorAll('#modal-donor-name').forEach(el => el.innerText = name || 'Unknown');
        document.querySelectorAll('#modal-donor-uid').forEach(el => el.innerText = uid);
        document.querySelectorAll('#modal-anon-uid').forEach(el => el.innerText = uid);
        document.querySelectorAll('#modal-donor-bg').forEach(el => el.innerText = bg);
        document.querySelectorAll('#modal-donor-donations, #modal-donor-donations-2, #modal-donor-donations-3').forEach(el => el.innerText = donations);
        
        document.getElementById('eraseInput').value = '';
        document.getElementById('eraseModalOverlay').style.display = 'flex';
    }

    function closeEraseModal() {
        currentEraseDonorId = null;
        document.getElementById('eraseModalOverlay').style.display = 'none';
    }

    async function actionRequest(url, rowIdToRemove, successMsg='Action successful') {
        try {
            const res = await fetch(url, { method: 'POST', headers: getHeaders() });
            if (res.ok) {
                showToast(successMsg);
                if (rowIdToRemove) {
                    const row = document.getElementById('donor-row-' + rowIdToRemove);
                    if (row) row.remove();
                } else {
                    fetchDonors();
                }
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

    async function exportData(id) {
        try {
            const res = await fetch(`http://127.0.0.1:8000/api/admin/donors/${id}/export/`, { headers: getHeaders() });
            if (res.ok) {
                const data = await res.json();
                const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
                const url = window.URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = `donor_export_${id}.json`;
                document.body.appendChild(a);
                a.click();
                a.remove();
                showToast('Export triggered successfully');
            } else {
                showToast('Export failed', true);
            }
        } catch(e) {
            showToast('Export error', true);
        }
    }

    function verifyDonor(id) {
        if (confirm('Mark donor as Hospital Verified?')) {
            actionRequest(`http://127.0.0.1:8000/api/admin/donors/${id}/verify/`, null, 'Donor Verified');
        }
    }

    function suspendDonor(id) {
        if (confirm('Suspend donor (set unavailable)?')) {
            actionRequest(`http://127.0.0.1:8000/api/admin/donors/${id}/suspend/`, null, 'Donor Suspended');
        }
    }

    document.addEventListener('DOMContentLoaded', () => {
        fetchDonors();

        document.getElementById('confirm-erase-btn')?.addEventListener('click', () => {
            const val = document.getElementById('eraseInput').value;
            if (val === 'CONFIRM_ERASE' && currentEraseDonorId) {
                // The soft delete endpoint uses the user ID or donor ID.
                // The view soft deletes based on the user object, but wait, the destroy method handles it?
                // Actually, the new views_admin_donors doesn't have erase, we should add it!
                // Wait! the user said: "call the existing soft-delete logic (same pattern verified in UserDeletionRetentionTest)".
                // That is DELETE /api/donors/<id>/ but it requires the donor id or "me".
                // Admin can delete any donor id via DELETE /api/donors/<id>/
                actionDelete(`http://127.0.0.1:8000/api/donors/${currentEraseDonorId}/`, currentEraseDonorId);
            } else {
                showToast('Type CONFIRM_ERASE to proceed', true);
            }
        });
    });

    async function actionDelete(url, id) {
        try {
            const res = await fetch(url, { method: 'DELETE', headers: getHeaders() });
            if (res.ok || res.status === 204) {
                showToast('Irreversible Erase Completed');
                closeEraseModal();
                fetchDonors();
            } else {
                showToast('Erase failed', true);
            }
        } catch(e) {
            showToast('Erase error', true);
        }
    }

    async function fetchDonors() {
        try {
            const res = await fetch('http://127.0.0.1:8000/api/admin/donors/', { headers: getHeaders() });
            if (res.ok) {
                const data = await res.json();
                renderDonors(data);
            } else if (res.status === 401 || res.status === 403) {
                window.location.href = 'admin-login.html';
            }
        } catch (e) {
            console.error(e);
        }
    }

    function renderDonors(data) {
        const container = document.getElementById('donor-table-body');
        if (data.length === 0) {
            container.innerHTML = '<tr><td colspan="5" class="p-5 text-center text-sm text-gray-500">No donors found.</td></tr>';
            return;
        }

        container.innerHTML = data.map(item => `
        <tr class="hover:bg-[#FDF3F3] transition-colors" id="donor-row-${item.id}">
            <td class="py-3.5 px-4">
                <div class="flex items-center gap-3">
                    <div class="relative">
                        <img alt="Avatar" class="w-10 h-10 rounded-full object-cover border border-[#EBDCDC]" src="https://i.pravatar.cc/150?u=${item.user_id}"/>
                        ${item.is_active ? 
                          '<span class="absolute bottom-0 right-0 w-3 h-3 rounded-full bg-emerald-500 border-2 border-white"></span>' : 
                          '<span class="absolute bottom-0 right-0 w-3 h-3 rounded-full bg-red-500 border-2 border-white"></span>'}
                    </div>
                    <div class="flex flex-col">
                        <div class="flex items-center gap-1.5">
                            <span class="text-sm font-bold text-[#2B2B2B]">${item.full_name}</span>
                            ${item.trust_score > 70 ? '<span class="material-symbols-outlined text-[14px] text-blue-500">verified</span>' : ''}
                        </div>
                        <div class="flex items-center gap-2 mt-0.5 text-[#6B7280]">
                            <span class="text-[11px]">${item.phone || item.email}</span>
                            <span class="w-1 h-1 rounded-full bg-[#EBDCDC]"></span>
                            <span class="text-[11px] font-mono">UID #D-${item.user_id}</span>
                        </div>
                    </div>
                </div>
            </td>
            <td class="py-3.5 px-4">
                <div class="flex flex-col">
                    <div class="flex items-center gap-1.5">
                        <span class="w-2.5 h-2.5 rounded-full ${item.blood_group ? 'bg-[#C30121]' : 'bg-gray-400'}"></span>
                        <span>${item.blood_group || 'Unknown'}</span>
                    </div>
                    <span class="text-[11px] text-[#6B7280]">${item.is_available ? 'Available' : 'Unavailable'}</span>
                </div>
            </td>
            <td class="py-3.5 px-4">
                <div class="flex items-center gap-1.5">
                    <span class="w-2.5 h-2.5 rounded-full ${item.is_active ? 'bg-emerald-500' : 'bg-red-500'}"></span>
                    <span class="text-xs font-semibold ${item.is_active ? 'text-emerald-700' : 'text-red-700'}">${item.is_active ? 'Active' : 'Erased/Banned'}</span>
                </div>
            </td>
            <td class="py-3.5 px-4">
                <div class="flex flex-col">
                    <span class="text-xs font-bold text-[#2B2B2B]">${item.total_donations} Bag(s) Donated</span>
                </div>
            </td>
            <td class="py-3.5 px-4">
                <div class="flex items-center gap-2">
                    <div class="w-7 h-7 rounded-full bg-[#FFDAD6] flex items-center justify-center font-bold text-xs text-[#BA1A1A]">${item.trust_score}</div>
                    <div class="flex flex-col">
                        <span class="text-xs font-semibold text-[#BA1A1A]">Band: ${item.trust_band}</span>
                    </div>
                </div>
            </td>
            <td class="py-3.5 px-4 text-right">
                <div class="inline-flex items-center gap-1 justify-end">
                    <button onclick="verifyDonor(${item.id})" class="p-1 rounded-full hover:bg-[#F0F7FD] text-[#0D68AA] transition-colors" type="button" title="Verify">
                        <span class="material-symbols-outlined text-[18px]">check_circle</span>
                    </button>
                    <button onclick="suspendDonor(${item.id})" class="p-1 rounded-full hover:bg-[#FAF0F0] text-[#594A4B] transition-colors" type="button" title="Suspend">
                        <span class="material-symbols-outlined text-[18px]">flip_camera_ios</span>
                    </button>
                    <button onclick="exportData(${item.id})" class="p-1 rounded-full hover:bg-[#F0F7FD] text-[#0D68AA] transition-colors" type="button" title="Export">
                        <span class="material-symbols-outlined text-[18px]">download</span>
                    </button>
                    <button onclick="openEraseModal(${item.id}, '${item.full_name.replace(/'/g, "\\'")}', '${item.user_id}', '${item.blood_group}', ${item.total_donations})" class="p-1 rounded-full hover:bg-[#FAF0F0] text-[#C30121] transition-colors" type="button" title="Full Erase">
                        <span class="material-symbols-outlined text-[18px]">delete_forever</span>
                    </button>
                </div>
            </td>
        </tr>
        `).join('');
    }
</script>
"""

html = html.replace('</body>', js_logic + '\n</body>')

with open('donor-management.html', 'w', encoding='utf-8') as f:
    f.write(html)
print("Updated donor-management.html!")
