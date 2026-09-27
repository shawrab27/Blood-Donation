import re

with open('trust-fraud-engine.html', 'r', encoding='utf-8') as f:
    content = f.read()

toast_html = '''
<!-- Notification Toast -->
<div class="fixed bottom-6 right-6 z-50 bg-[#2B2B2B] text-white px-md py-sm rounded-lg shadow-xl flex items-center gap-sm transform translate-y-20 opacity-0 transition-all duration-300 pointer-events-none" id="toast">
<span class="material-symbols-outlined text-[20px] text-red-300" id="toast-icon">check_circle</span>
<span class="font-body-sm text-body-sm" id="toast-message">Action executed successfully</span>
</div>
'''
if 'id="toast"' not in content:
    content = content.replace('</body>', toast_html + '\n</body>')

modal_html = '''
<!-- Ban Confirmation Modal -->
<div id="ban-modal" class="fixed inset-0 z-50 hidden items-center justify-center bg-black/50">
    <div class="bg-white rounded-lg p-6 max-w-md w-full shadow-xl">
        <h2 class="text-xl font-bold text-[#2B2B2B] mb-4">Confirm Permanent Ban</h2>
        <p class="text-[#543f3e] mb-4">Are you sure you want to permanently ban user <strong id="modal-ban-user-id"></strong>?</p>
        <p class="text-[#C30121] text-sm mb-6 font-semibold">This will soft-delete their profile, wipe PII, and prevent login.</p>
        <div class="flex justify-end gap-3">
            <button onclick="closeBanModal()" class="px-4 py-2 rounded font-semibold text-neutral-600 bg-neutral-200 hover:bg-neutral-300">Cancel</button>
            <button id="confirm-ban-btn" class="px-4 py-2 rounded font-semibold text-white bg-[#C30121] hover:bg-[#a9001b] inline-flex items-center gap-2">
                <span class="material-symbols-outlined text-[18px]">gavel</span> Confirm Ban
            </button>
        </div>
    </div>
</div>
'''
if 'id="ban-modal"' not in content:
    content = content.replace('</body>', modal_html + '\n</body>')

content = content.replace('>Base Score<', '>NID/OCR weight<')
content = content.replace('>Hospital Verified<', '>Donation Fulfillment weight<')
content = content.replace('>Prescription Slip<', '>Community Vouching weight<')
content = content.replace('>No Show Penalty<', '>Anomaly Penalty weight<')

content = content.replace('>Anomaly Signal Breakdown (24h)<', '><span class="text-neutral-400">Anomaly Signal Breakdown (Not implemented - Pending Backend Module)</span><')

new_js = r'''
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

    let currentBanUserId = null;
    function openBanModal(userId) {
        currentBanUserId = userId;
        document.getElementById('modal-ban-user-id').innerText = '#' + userId;
        document.getElementById('ban-modal').classList.remove('hidden');
        document.getElementById('ban-modal').classList.add('flex');
    }
    
    function closeBanModal() {
        currentBanUserId = null;
        document.getElementById('ban-modal').classList.add('hidden');
        document.getElementById('ban-modal').classList.remove('flex');
    }
    
    document.addEventListener('DOMContentLoaded', () => {
        const confirmBanBtn = document.getElementById('confirm-ban-btn');
        if(confirmBanBtn){
            confirmBanBtn.addEventListener('click', () => {
                if (currentBanUserId) {
                    actionRequest(http://127.0.0.1:8000/api/admin/trust-engine/users//ban/, null, 'User banned successfully');
                    closeBanModal();
                }
            });
        }
    });

    function renderQueue(data) {
        const container = document.getElementById('quarantine-queue-container');
        if (data.length === 0) {
            container.innerHTML = '<div class="p-5 text-center text-sm text-gray-500 font-medium">Queue is currently empty.</div>';
            return;
        }
        
        container.innerHTML = data.map(item => 
        <div class="p-4 hover:bg-[#FAF0F0]/60 transition-colors" id="req-row-">
            <div class="flex items-start justify-between gap-3">
                <div class="flex items-center gap-3 flex-1 min-w-0">
                    <div class="w-9 h-9 rounded-full bg-[#FFDAD6] flex items-center justify-center text-[#BA1A1A] font-bold text-xs shrink-0"></div>
                    <div class="truncate">
                        <div class="flex items-center gap-1.5">
                            <span class="text-sm font-bold text-[#2B2B2B]"></span>
                            <span class="px-1.5 py-0.5 rounded bg-[#FFDAD7] text-[#930016] text-[10px] font-bold">Q-FLAG</span>
                        </div>
                        <p class="text-[11px] text-[#6B7280] truncate">Req # &bull; OCR: <span class="text-neutral-400">Not tracked yet</span> &bull; Anomaly: <span class="text-neutral-400">Not tracked yet</span></p>
                    </div>
                </div>
                <div class="text-right shrink-0">
                    <span class="text-sm font-bold text-[#BA1A1A]">Score: </span>
                    <p class="text-[10px] text-[#6B7280]">Risk: High (LOW BAND)</p>
                </div>
            </div>
            <div class="mt-2.5 flex items-center gap-1.5 justify-end">
                <button onclick="approveRequest()" class="inline-flex items-center gap-1 px-3 py-1 rounded-full bg-emerald-600 text-white text-[11px] font-semibold hover:bg-emerald-700 transition-colors shadow-sm" type="button"><span class="material-symbols-outlined text-[14px]">check</span> Approve</button>
                <button onclick="rejectRequest()" class="inline-flex items-center gap-1 px-3 py-1 rounded-full bg-orange-600 text-white text-[11px] font-semibold hover:bg-orange-700 transition-colors shadow-sm" type="button"><span class="material-symbols-outlined text-[14px]">close</span> Reject</button>
                <button onclick="openBanModal()" class="inline-flex items-center gap-1 px-3 py-1 rounded-full bg-[#C30121] text-white text-[11px] font-semibold hover:bg-[#A1001B] transition-colors shadow-sm" type="button"><span class="material-symbols-outlined text-[14px]">gavel</span> Ban</button>
            </div>
        </div>
        ).join('');
    }
    
    async function actionRequest(url, rowIdToRemove, successMsg='Action successful') {
        try {
            const res = await fetch(url, { method: 'POST', headers: getHeaders() });
            if (res.ok) {
                showToast(successMsg);
                if (rowIdToRemove) {
                    const row = document.getElementById('req-row-' + rowIdToRemove);
                    if (row) row.remove();
                } else {
                    fetchQuarantineQueue(); // full refresh if ban
                }
            } else {
                showToast('Action failed', true);
            }
        } catch (e) {
            console.error(e);
            showToast('Network error', true);
        }
    }
    
    function approveRequest(id) {
        if (confirm('Approve this request and move it to MEDIUM trust band?')) {
            actionRequest(http://127.0.0.1:8000/api/admin/trust-engine/cases//approve/, id, 'Request Approved');
        }
    }
    
    function rejectRequest(id) {
        if (confirm('Permanently reject this request?')) {
            actionRequest(http://127.0.0.1:8000/api/admin/trust-engine/cases//reject/, id, 'Request Rejected');
        }
    }
'''

content = re.sub(r'function renderQueue\(data\).*?function banUser\(userId\) \{.*?\}', new_js, content, flags=re.DOTALL)

# Re-add getHeaders if it's not present (it should be)
with open('trust-fraud-engine.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("HTML script applied successfully.")
