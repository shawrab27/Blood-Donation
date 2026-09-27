import os
from bs4 import BeautifulSoup

def update_html():
    filepath = 'trust-fraud-engine.html'
    with open(filepath, 'r', encoding='utf-8') as f:
        soup = BeautifulSoup(f, 'lxml')

    # Update Sliders container
    sliders_container = soup.find('div', class_='p-6 space-y-5')
    if sliders_container:
        sliders_container.clear()
        
        # We will inject 4 sliders that match the backend TrustScoreConfig
        sliders_html = """
        <!-- Base Score -->
        <div class="space-y-2">
            <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                    <span class="material-symbols-outlined text-[18px] text-[#0D68AA]">speed</span>
                    <div>
                        <p class="text-xs font-bold text-[#2B2B2B]">Base Trust Score</p>
                        <p class="text-[11px] text-[#6B7280]">Default starting score for new requests</p>
                    </div>
                </div>
                <span class="text-sm font-bold text-[#C30121] font-mono" id="val-base_score">50 pts</span>
            </div>
            <input id="slider-base_score" class="w-full h-2 rounded-full cursor-pointer accent-[#C30121]" max="100" min="0" oninput="document.getElementById('val-base_score').innerText=this.value+' pts'" step="1" type="range" value="50"/>
        </div>
        
        <!-- Hospital Verified Bonus -->
        <div class="space-y-2">
            <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                    <span class="material-symbols-outlined text-[18px] text-[#0D68AA]">local_hospital</span>
                    <div>
                        <p class="text-xs font-bold text-[#2B2B2B]">Verified Hospital Bonus</p>
                        <p class="text-[11px] text-[#6B7280]">Bonus points if the hospital is in the verified registry</p>
                    </div>
                </div>
                <span class="text-sm font-bold text-[#C30121] font-mono" id="val-hospital_verified">+15 pts</span>
            </div>
            <input id="slider-hospital_verified" class="w-full h-2 rounded-full cursor-pointer accent-[#C30121]" max="50" min="0" oninput="document.getElementById('val-hospital_verified').innerText='+'+this.value+' pts'" step="1" type="range" value="15"/>
        </div>
        
        <!-- Prescription Slip Bonus -->
        <div class="space-y-2">
            <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                    <span class="material-symbols-outlined text-[18px] text-[#0D68AA]">receipt_long</span>
                    <div>
                        <p class="text-xs font-bold text-[#2B2B2B]">Prescription Slip Bonus</p>
                        <p class="text-[11px] text-[#6B7280]">Bonus if AI verifies the requisition document</p>
                    </div>
                </div>
                <span class="text-sm font-bold text-[#C30121] font-mono" id="val-prescription_slip">+20 pts</span>
            </div>
            <input id="slider-prescription_slip" class="w-full h-2 rounded-full cursor-pointer accent-[#C30121]" max="50" min="0" oninput="document.getElementById('val-prescription_slip').innerText='+'+this.value+' pts'" step="1" type="range" value="20"/>
        </div>
        
        <!-- No Show Penalty -->
        <div class="space-y-2">
            <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                    <span class="material-symbols-outlined text-[18px] text-[#0D68AA]">person_cancel</span>
                    <div>
                        <p class="text-xs font-bold text-[#2B2B2B]">No-Show Penalty</p>
                        <p class="text-[11px] text-[#6B7280]">Points deducted per historical donor no-show</p>
                    </div>
                </div>
                <span class="text-sm font-bold text-[#C30121] font-mono" id="val-no_show_penalty">-25 pts</span>
            </div>
            <input id="slider-no_show_penalty" class="w-full h-2 rounded-full cursor-pointer accent-[#C30121]" max="50" min="0" oninput="document.getElementById('val-no_show_penalty').innerText='-'+this.value+' pts'" step="1" type="range" value="25"/>
        </div>

        <div class="flex items-center justify-between pt-2 border-t border-[#F5E9E9]">
            <p class="text-xs text-[#6B7280]" id="save-status"></p>
            <button onclick="saveTrustWeights()" class="inline-flex items-center gap-1.5 px-5 py-2 rounded-full bg-[#C30121] text-white text-xs font-semibold shadow-sm hover:bg-[#A1001B] transition-colors" type="button">
                <span class="material-symbols-outlined text-[17px]">save</span><span>Commit Weight Configuration</span>
            </button>
        </div>
        """
        sliders_container.append(BeautifulSoup(sliders_html, 'html.parser'))
        
    # Find the active queue div and replace with a dynamic container
    # It has class "divide-y divide-[#F5E9E9]" inside the Active Triage Queue
    queue_container = soup.find('div', class_='divide-y divide-[#F5E9E9]')
    if queue_container:
        queue_container.clear()
        queue_container['id'] = 'quarantine-queue-container'
        queue_container.append(BeautifulSoup('<div class="p-4 text-sm text-gray-500 text-center">Loading quarantine queue...</div>', 'html.parser'))
        
    # Inject JS scripts for fetching and updating
    js_code = """
<script>
    function getHeaders() {
        const token = localStorage.getItem('access_token');
        return {
            'Content-Type': 'application/json',
            'Authorization': token ? `Bearer ${token}` : ''
        };
    }

    async function fetchTrustWeights() {
        try {
            const res = await fetch('http://127.0.0.1:8000/api/admin/trust-engine/weights/', {
                headers: getHeaders()
            });
            if (res.ok) {
                const data = await res.json();
                document.getElementById('slider-base_score').value = data.base_score;
                document.getElementById('val-base_score').innerText = data.base_score + ' pts';
                
                document.getElementById('slider-hospital_verified').value = data.hospital_verified;
                document.getElementById('val-hospital_verified').innerText = '+' + data.hospital_verified + ' pts';
                
                document.getElementById('slider-prescription_slip').value = data.prescription_slip;
                document.getElementById('val-prescription_slip').innerText = '+' + data.prescription_slip + ' pts';
                
                document.getElementById('slider-no_show_penalty').value = data.no_show_penalty;
                document.getElementById('val-no_show_penalty').innerText = '-' + data.no_show_penalty + ' pts';
            } else if (res.status === 401 || res.status === 403) {
                window.location.href = 'admin-login.html';
            }
        } catch (e) {
            console.error(e);
        }
    }
    
    async function saveTrustWeights() {
        const payload = {
            base_score: document.getElementById('slider-base_score').value,
            hospital_verified: document.getElementById('slider-hospital_verified').value,
            prescription_slip: document.getElementById('slider-prescription_slip').value,
            no_show_penalty: document.getElementById('slider-no_show_penalty').value
        };
        const statusElem = document.getElementById('save-status');
        statusElem.innerText = 'Saving...';
        
        try {
            const res = await fetch('http://127.0.0.1:8000/api/admin/trust-engine/weights/', {
                method: 'POST',
                headers: getHeaders(),
                body: JSON.stringify(payload)
            });
            if (res.ok) {
                statusElem.innerText = 'Saved successfully!';
                statusElem.className = 'text-xs text-emerald-600 font-bold';
                setTimeout(() => { statusElem.innerText = ''; statusElem.className = 'text-xs text-[#6B7280]'; }, 3000);
            } else {
                statusElem.innerText = 'Failed to save.';
                statusElem.className = 'text-xs text-red-600 font-bold';
            }
        } catch (e) {
            console.error(e);
            statusElem.innerText = 'Error saving.';
        }
    }

    async function fetchQuarantineQueue() {
        try {
            const res = await fetch('http://127.0.0.1:8000/api/admin/trust-engine/queue/', {
                headers: getHeaders()
            });
            if (res.ok) {
                const data = await res.json();
                renderQueue(data);
            }
        } catch (e) {
            console.error(e);
        }
    }
    
    function renderQueue(data) {
        const container = document.getElementById('quarantine-queue-container');
        if (data.length === 0) {
            container.innerHTML = '<div class="p-5 text-center text-sm text-gray-500 font-medium">Queue is currently empty.</div>';
            return;
        }
        
        container.innerHTML = data.map(item => `
        <div class="p-4 hover:bg-[#FAF0F0]/60 transition-colors" id="req-row-${item.id}">
            <div class="flex items-start justify-between gap-3">
                <div class="flex items-center gap-3 flex-1 min-w-0">
                    <div class="w-9 h-9 rounded-full bg-[#FFDAD6] flex items-center justify-center text-[#BA1A1A] font-bold text-xs shrink-0">${item.blood_group}</div>
                    <div class="truncate">
                        <div class="flex items-center gap-1.5">
                            <span class="text-sm font-bold text-[#2B2B2B]">${item.patient_name}</span>
                            <span class="px-1.5 py-0.5 rounded bg-[#FFDAD7] text-[#930016] text-[10px] font-bold">Q-FLAG</span>
                        </div>
                        <p class="text-[11px] text-[#6B7280] truncate">Req #${item.id} &bull; OCR: <span class="text-neutral-400">N/A (Pending AI module)</span> &bull; Anomaly: <span class="text-neutral-400">N/A (Pending model)</span></p>
                    </div>
                </div>
                <div class="text-right shrink-0">
                    <span class="text-sm font-bold text-[#BA1A1A]">Score: ${item.trust_score}</span>
                    <p class="text-[10px] text-[#6B7280]">Risk: High (LOW BAND)</p>
                </div>
            </div>
            <div class="mt-2.5 flex items-center gap-1.5 justify-end">
                <button onclick="approveRequest(${item.id})" class="px-3 py-1 rounded-full bg-emerald-600 text-white text-[11px] font-semibold hover:bg-emerald-700 transition-colors shadow-sm" type="button">Approve (Restore)</button>
                <button onclick="rejectRequest(${item.id})" class="px-3 py-1 rounded-full bg-orange-600 text-white text-[11px] font-semibold hover:bg-orange-700 transition-colors shadow-sm" type="button">Reject Request</button>
                <button onclick="banUser(${item.requester_id})" class="px-3 py-1 rounded-full bg-[#C30121] text-white text-[11px] font-semibold hover:bg-[#A1001B] transition-colors shadow-sm" type="button">Permanent Ban</button>
            </div>
        </div>
        `).join('');
    }
    
    async function actionRequest(url, rowIdToRemove) {
        try {
            const res = await fetch(url, { method: 'POST', headers: getHeaders() });
            if (res.ok) {
                if (rowIdToRemove) {
                    const row = document.getElementById('req-row-' + rowIdToRemove);
                    if (row) row.remove();
                } else {
                    fetchQuarantineQueue(); // full refresh if ban
                }
            } else {
                alert('Action failed.');
            }
        } catch (e) {
            console.error(e);
        }
    }
    
    function approveRequest(id) {
        if (confirm('Approve this request and move it to MEDIUM trust band?')) {
            actionRequest(`http://127.0.0.1:8000/api/admin/trust-engine/cases/${id}/approve/`, id);
        }
    }
    
    function rejectRequest(id) {
        if (confirm('Permanently reject this request?')) {
            actionRequest(`http://127.0.0.1:8000/api/admin/trust-engine/cases/${id}/reject/`, id);
        }
    }
    
    function banUser(userId) {
        if (!userId) { alert("User ID missing or anon request."); return; }
        if (confirm('Permanently ban this user? This will soft-delete their profile, wipe PII, and prevent login.')) {
            actionRequest(`http://127.0.0.1:8000/api/admin/trust-engine/users/${userId}/ban/`, null);
        }
    }

    document.addEventListener('DOMContentLoaded', () => {
        fetchTrustWeights();
        fetchQuarantineQueue();
        
        // Polling queue every 10 seconds
        setInterval(fetchQuarantineQueue, 10000);
    });
</script>
"""
    if 'fetchTrustWeights()' not in str(soup):
        soup.body.append(BeautifulSoup(js_code, 'html.parser'))
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(str(soup))
    print("Updated trust-fraud-engine.html successfully.")

update_html()
