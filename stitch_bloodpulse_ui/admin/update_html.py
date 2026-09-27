from bs4 import BeautifulSoup

with open('wave-engine-control.html', 'r', encoding='utf-8') as f:
    soup = BeautifulSoup(f, 'lxml')

# 1. Update Metrics IDs
spans = soup.find_all('span', string=lambda t: t and 'Active Escalations' in t)
if spans:
    spans[0].find_next_sibling('div')['id'] = 'metric-active-escalations'

spans = soup.find_all('span', string=lambda t: t and 'Wave 1 Donors Pinged' in t)
if spans:
    spans[0].find_next_sibling('div')['id'] = 'metric-wave1-donors'

spans = soup.find_all('span', string=lambda t: t and 'Wave 4 Broadcasts' in t)
if spans:
    spans[0].find_next_sibling('div')['id'] = 'metric-wave4-broadcasts'

spans = soup.find_all('span', string=lambda t: t and 'Avg Time to Match' in t)
if spans:
    spans[0].find_next_sibling('div')['id'] = 'metric-avg-time'

# 2. Add ID to tbody and clear hardcoded rows
tbody = soup.find('tbody')
if tbody:
    tbody['id'] = 'pipeline-table-body'
    tbody.clear() # Removes static rows

# 3. Replace script tag
script_tag = soup.find_all('script')[-1]
new_script_content = """
  const API_URL = 'http://127.0.0.1:8000/api';
  
  // Try to find the auth token from local storage (commonly used in these setups)
  function getAuthToken() {
    return localStorage.getItem('access_token') || localStorage.getItem('adminToken') || '';
  }
  
  function getHeaders() {
    const token = getAuthToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': token ? `Bearer ${token}` : ''
    };
  }

  let refreshActive = true;
  let currentForceEscalateCaseId = null;
  const toggleBtn = document.getElementById('toggle-refresh');
  const pingRing = document.getElementById('ping-ring');
  const refreshIcon = document.getElementById('refresh-icon');

  toggleBtn.addEventListener('click', () => {
    refreshActive = !refreshActive;
    if (refreshActive) {
      pingRing.classList.remove('hidden');
      refreshIcon.classList.add('text-[#C30121]');
      showToast('Live telemetry auto-refresh resumed (5s interval)');
      fetchLivePipeline(); // Immediate fetch on resume
    } else {
      pingRing.classList.add('hidden');
      refreshIcon.classList.add('text-[#757575]');
      showToast('Live telemetry auto-refresh paused');
    }
  });

  document.getElementById('btn-force-tick').addEventListener('click', () => {
    showToast('Manual fetch triggered');
    fetchDashboardMetrics();
    fetchLivePipeline();
  });

  const modal = document.getElementById('escalation-modal');

  function openEscalationModal(caseId, hospital, blood, fromStage, toStage, fromRad, toRad, donors) {
    currentForceEscalateCaseId = caseId;
    document.getElementById('modal-case-id').innerText = '#' + caseId;
    document.getElementById('modal-hospital').innerText = hospital;
    document.getElementById('modal-blood').innerText = blood;
    document.getElementById('modal-from-stage').innerText = fromStage;
    document.getElementById('modal-to-stage').innerText = toStage;
    document.getElementById('modal-radius').innerText = fromRad + ' -> ' + toRad;
    document.getElementById('modal-donors').innerText = donors;
    modal.classList.remove('hidden');
  }

  function closeEscalationModal() { 
    currentForceEscalateCaseId = null;
    modal.classList.add('hidden'); 
  }

  async function executeEscalation() {
    if (!currentForceEscalateCaseId) return;
    const caseId = currentForceEscalateCaseId;
    closeEscalationModal();
    
    try {
      const response = await fetch(`${API_URL}/admin/cases/${caseId}/force-escalate/`, {
        method: 'POST',
        headers: getHeaders()
      });
      
      const data = await response.json();
      
      if (!response.ok) {
        showToast(data.error || 'Failed to escalate request', true);
        return;
      }
      
      showToast(`Escalated to Wave ${data.new_wave}. Notified ${data.donors_notified} new donors. radius: ${data.new_radius_km}km`);
      fetchDashboardMetrics();
      fetchLivePipeline();
    } catch (err) {
      showToast('Network error during escalation', true);
    }
  }

  const drawer = document.getElementById('radar-drawer');

  function toggleRadarDrawer(caseId) {
    document.getElementById('drawer-case-id').innerText = '#' + caseId;
    drawer.classList.remove('translate-x-full');
  }

  function closeRadarDrawer() { drawer.classList.add('translate-x-full'); }

  function showToast(message, isError = false) {
    const toast = document.getElementById('toast');
    const toastIcon = document.getElementById('toast-icon');
    
    document.getElementById('toast-message').innerText = message;
    
    if (isError) {
      toastIcon.innerText = 'error';
      toastIcon.classList.replace('text-red-300', 'text-[#C30121]');
    } else {
      toastIcon.innerText = 'check_circle';
      toastIcon.classList.replace('text-[#C30121]', 'text-red-300');
    }

    toast.classList.remove('translate-y-20', 'opacity-0');
    toast.classList.add('translate-y-0', 'opacity-100');
    setTimeout(() => {
      toast.classList.add('translate-y-20', 'opacity-0');
      toast.classList.remove('translate-y-0', 'opacity-100');
    }, 4000);
  }

  // --- NEW FETCH LOGIC --- //

  async function fetchDashboardMetrics() {
    try {
      const res = await fetch(`${API_URL}/admin/wave-engine/metrics/`, {
        headers: getHeaders()
      });
      if (!res.ok) throw new Error('Failed to fetch metrics');
      const data = await res.json();
      
      document.getElementById('metric-active-escalations').innerText = data.active_escalations;
      document.getElementById('metric-wave1-donors').innerText = data.wave1_donors_pinged;
      document.getElementById('metric-wave4-broadcasts').innerText = data.wave4_broadcasts;
      
      const timeDiv = document.getElementById('metric-avg-time');
      if (data.avg_match_time_minutes === null) {
        timeDiv.innerHTML = `<span class="text-headline-md font-headline-md text-[#757575]">Not enough data</span>`;
      } else {
        timeDiv.innerHTML = `${data.avg_match_time_minutes} <span class="text-headline-md font-headline-md text-[#757575]">min</span>`;
      }
    } catch (e) {
      console.error(e);
      showToast('Error loading telemetry metrics', true);
    }
  }

  function getTimeAgo(dateString) {
    const diff = Math.floor((new Date() - new Date(dateString)) / 1000);
    if (diff < 60) return diff + "s ago";
    if (diff < 3600) return Math.floor(diff / 60) + "m ago";
    return Math.floor(diff / 3600) + "h ago";
  }

  async function fetchLivePipeline() {
    try {
      const res = await fetch(`${API_URL}/admin/wave-engine/live-pipeline/`, {
        headers: getHeaders()
      });
      if (!res.ok) throw new Error('Failed to fetch pipeline');
      const data = await res.json();
      
      const tbody = document.getElementById('pipeline-table-body');
      tbody.innerHTML = '';
      
      if (data.length === 0) {
        tbody.innerHTML = `<tr><td colspan="7" class="py-lg text-center text-[#757575]">No active escalations currently.</td></tr>`;
        return;
      }
      
      data.forEach(item => {
        let waveBadgeClass = item.current_wave >= 4 ? 'bg-[#C30121]/10 text-[#C30121]' :
                             item.current_wave === 3 ? 'bg-[#0D68AA]/10 text-[#0D68AA]' :
                             'bg-neutral-100 text-[#5A5A5A]';
        let isWave4 = item.current_wave >= 4;
        let btnDisabled = isWave4 ? 'disabled opacity-50 cursor-not-allowed' : '';
        
        // Setup variables for Force Escalation Modal
        let fromWave = item.current_wave;
        let toWave = Math.min(item.current_wave + 1, 4);
        let radius = item.search_radius_km;
        let nextRadius = toWave === 1 ? 5.0 : toWave === 2 ? 25.0 : toWave === 3 ? 100.0 : 150.0;
        
        const rowHTML = `
          <tr class="hover:bg-[#FDF3F3]/70 transition-colors">
            <td class="py-3.5 px-4 font-semibold text-[#C30121]">#BP-${item.id}</td>
            <td class="py-3.5 px-4">
              <span class="inline-flex items-center justify-center px-1.5 py-0.5 rounded bg-neutral-100 border border-neutral-200 text-xs font-bold text-[#C30121]">
                ${item.blood_group}
              </span>
            </td>
            <td class="py-3.5 px-4"><span class="truncate block max-w-[150px] font-medium" title="${item.hospital_name}">${item.hospital_name}</span></td>
            <td class="py-3.5 px-4">
              <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full ${waveBadgeClass} text-xs font-bold">
                Wave ${item.current_wave} &middot; ${item.escalation_status}
              </span>
            </td>
            <td class="py-3.5 px-4">
              <div class="flex items-center gap-2">
                <div class="w-full bg-neutral-200 rounded-full h-1.5 max-w-[60px] overflow-hidden flex">
                  <div class="bg-[#0D68AA] h-1.5" style="width: ${Math.min((item.accepted_donors_count / Math.max(item.pinged_donors_count, 1)) * 100, 100)}%"></div>
                </div>
                <span class="text-xs text-[#5A5A5A]">
                  <strong class="text-[#2B2B2B]">${item.accepted_donors_count}</strong>/${item.pinged_donors_count}
                </span>
              </div>
            </td>
            <td class="py-3.5 px-4 text-[#757575] text-xs">T+${getTimeAgo(item.created_at)}</td>
            <td class="py-3.5 px-4 text-right">
              <div class="flex items-center justify-end gap-1">
                <button type="button" onclick="toggleRadarDrawer(${item.id})" class="p-1 rounded text-[#757575] hover:bg-neutral-100 hover:text-[#0D68AA] transition-colors tooltip-trigger relative" title="View Radar">
                  <span class="material-symbols-outlined text-[18px]">radar</span>
                </button>
                <button type="button" ${btnDisabled} onclick="openEscalationModal(${item.id}, '${item.hospital_name.replace(/'/g, "\\'")}', '${item.blood_group}', 'Wave ${fromWave}', 'Wave ${toWave}', '${radius}km', '${nextRadius}km', 'Calculate from backend...')" class="p-1 rounded text-[#757575] hover:bg-[#FDF3F3] hover:text-[#C30121] transition-colors tooltip-trigger relative" title="Force Next Wave">
                  <span class="material-symbols-outlined text-[18px]">fast_forward</span>
                </button>
              </div>
            </td>
          </tr>
        `;
        tbody.insertAdjacentHTML('beforeend', rowHTML);
      });
    } catch (e) {
      console.error(e);
      // Fail silently for background polling to not spam toasts, unless it's initial load.
    }
  }

  // Initialization
  document.addEventListener("DOMContentLoaded", () => {
    fetchDashboardMetrics();
    fetchLivePipeline();
    
    // Auto refresh interval (every 5 seconds)
    setInterval(() => {
      if (refreshActive) {
        fetchLivePipeline();
      }
    }, 5000);
  });
"""
script_tag.string = new_script_content

with open('wave-engine-control.html', 'w', encoding='utf-8') as f:
    f.write(str(soup))
