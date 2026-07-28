// AniVerse Studio — Admin CMS Logic & Data Engine

const DEFAULT_PIN = "8888";
const STORAGE_PIN_KEY = "aniverse_admin_pin";
const STORAGE_CATALOG_KEY = "user_catalog_v1";

// Initial Catalog Preset
let defaultCatalog = [
  {
    id: "101055",
    title: "Cyberpunk Edgerunners",
    imageUrl: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx120377-ayZPoxiWt4Li.jpg",
    rating: 9.5,
    genres: ["Sci-Fi", "Action", "Drama"],
    description: "A street kid trying to survive in a technology and body modification-obsessed city of the future.",
    isTrending: true,
    releaseDay: 5,
    episodes: 10,
    trailerUrl: "https://www.youtube.com/watch?v=JtqIas3bYhg",
    catalogEpisodeLink: ""
  },
  {
    id: "145064",
    title: "Demon Slayer",
    imageUrl: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx101922-WBsBl0ClmgYL.jpg",
    rating: 9.2,
    genres: ["Action", "Fantasy", "Adventure"],
    description: "A family is attacked by demons and only two members survive.",
    isTrending: true,
    releaseDay: 7,
    episodes: 26,
    trailerUrl: "https://www.youtube.com/watch?v=VQGCKyvzIM4",
    catalogEpisodeLink: ""
  },
  {
    id: "113415",
    title: "Jujutsu Kaisen",
    imageUrl: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx113415-LHBAeoZDIsnF.jpg",
    rating: 9.0,
    genres: ["Fantasy", "Action", "Horror"],
    description: "A boy swallows a cursed object and becomes a vessel for a powerful curse.",
    isTrending: true,
    releaseDay: 3,
    episodes: 24,
    trailerUrl: "https://www.youtube.com/watch?v=pkNEKBmflg8",
    catalogEpisodeLink: ""
  },
  {
    id: "custom-frieren",
    title: "Sousou no Frieren",
    imageUrl: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx154587-qQTzQnEJJ3oB.jpg",
    rating: 9.26,
    genres: ["Adventure", "Award Winning", "Drama"],
    description: "During a decade-long quest to defeat the Demon King, the members of the hero party forge bonds through adventures and battles.",
    isTrending: true,
    releaseDay: 5,
    episodes: 28,
    placement: ["explore", "jadwal", "home_trending"],
    trailerUrl: "",
    catalogEpisodeLink: ""
  },
  {
    id: "custom-mushoku-tensei",
    title: "Mushoku Tensei: Isekai Ittara Honki Dasu",
    imageUrl: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx108465-1ANspF1EWyFx.jpg",
    rating: 8.7,
    genres: ["Fantasy", "Adventure"],
    description: "A shut-in is reincarnated into a magical world as Rudeus Greyrat and resolves to live this new life without regrets.",
    isTrending: false,
    releaseDay: 5,
    episodes: 11,
    placement: ["explore", "jadwal"],
    trailerUrl: "",
    catalogEpisodeLink: ""
  }
];

let catalogData = [];
let activeFilter = 'all';

// Initialize
document.addEventListener("DOMContentLoaded", () => {
  checkAuthSession();
  loadCatalogData();
});

// Authentication System
function getAdminPIN() {
  return localStorage.getItem(STORAGE_PIN_KEY) || DEFAULT_PIN;
}

function checkAuthSession() {
  const isAuth = sessionStorage.getItem("aniverse_admin_authenticated");
  if (isAuth === "true") {
    document.getElementById("auth-modal").classList.add("hidden");
    document.getElementById("app-dashboard").classList.remove("hidden");
    renderCatalog();
  } else {
    document.getElementById("auth-modal").classList.remove("hidden");
    document.getElementById("app-dashboard").classList.add("hidden");
  }
}

function handleLogin(e) {
  e.preventDefault();
  const inputPin = document.getElementById("admin-pin").value;
  const currentPin = getAdminPIN();

  if (inputPin === currentPin) {
    sessionStorage.setItem("aniverse_admin_authenticated", "true");
    document.getElementById("auth-error").classList.add("hidden");
    checkAuthSession();
  } else {
    document.getElementById("auth-error").classList.remove("hidden");
  }
}

function handleLogout() {
  sessionStorage.removeItem("aniverse_admin_authenticated");
  checkAuthSession();
}

function handleChangePin(e) {
  e.preventDefault();
  const newPin = document.getElementById("new-pin").value.trim();
  if (newPin.length < 4) {
    alert("PIN minimal 4 karakter!");
    return;
  }
  localStorage.setItem(STORAGE_PIN_KEY, newPin);
  alert("PIN Admin berhasil diubah!");
  document.getElementById("new-pin").value = "";
}

// Catalog Data Engine
function loadCatalogData() {
  const stored = localStorage.getItem(STORAGE_CATALOG_KEY);
  if (stored) {
    try {
      catalogData = JSON.parse(stored);
    } catch (err) {
      catalogData = [...defaultCatalog];
    }
  } else {
    catalogData = [...defaultCatalog];
    saveCatalogData();
  }
}

function saveCatalogData() {
  localStorage.setItem(STORAGE_CATALOG_KEY, JSON.stringify(catalogData));
  renderCatalog();
}

function renderCatalog() {
  const grid = document.getElementById("anime-grid");
  const searchQuery = document.getElementById("search-input").value.toLowerCase().trim();

  let filtered = catalogData.filter(item => {
    const matchesSearch = item.title.toLowerCase().includes(searchQuery);
    if (!matchesSearch) return false;

    if (activeFilter === 'trending') return item.isTrending;
    if (activeFilter === 'custom') return item.id.startsWith('custom-');
    return true;
  });

  // Update counts
  document.getElementById("count-all").textContent = catalogData.length;
  document.getElementById("count-trending").textContent = catalogData.filter(x => x.isTrending).length;
  document.getElementById("count-custom").textContent = catalogData.filter(x => x.id.startsWith('custom-')).length;

  if (filtered.length === 0) {
    grid.innerHTML = `
      <div style="grid-column: 1/-1; text-align: center; padding: 60px 20px; color: #94a3b8;">
        <p style="font-size: 32px; margin-bottom: 8px;">🎬</p>
        <p style="font-weight: 600; font-size: 16px;">Tidak ada anime yang ditemukan</p>
        <p style="font-size: 13px;">Tekan tombol "+ Tambah Anime" untuk menambahkan karya baru.</p>
      </div>
    `;
    return;
  }

  grid.innerHTML = filtered.map(item => `
    <div class="anime-card-admin">
      <div class="card-cover" style="background-image: url('${item.imageUrl}')">
        <div class="card-badges">
          ${item.isTrending ? '<span class="badge-tag trending">🔥 Trending</span>' : ''}
          <span class="badge-tag">★ ${item.rating || '8.0'}</span>
        </div>
      </div>
      <div class="card-body">
        <h4>${escapeHtml(item.title)}</h4>
        <p>${escapeHtml(item.description)}</p>
        <div class="card-meta">
          <span class="meta-pill">📺 ${item.episodes || 12} Ep</span>
          <span class="meta-pill" style="color: ${item.status === 'Finished Airing' ? '#a855f7' : '#22c55e'}; font-weight:700;">
            ${item.status === 'Finished Airing' ? '🏁 Tamat' : '🟢 On-Going'}
          </span>
          ${item.trailerUrl ? '<span class="meta-pill" style="color:#00f2fe;">🎬 Trailer</span>' : ''}
          ${item.catalogEpisodeLink ? '<span class="meta-pill" style="color:#2ed573;">▶ Stream</span>' : ''}
        </div>
        <div class="card-actions">
          <button class="btn-icon" onclick="editAnime('${item.id}')">✏ Edit</button>

          <button class="btn-icon delete" onclick="deleteAnime('${item.id}')">🗑 Hapus</button>
        </div>
      </div>
    </div>
  `).join('');
}

// Search & Filter Tabs
function handleSearch() {
  renderCatalog();
}

function filterCategory(cat, el) {
  activeFilter = cat;
  document.querySelectorAll('.filter-bar .chip').forEach(c => c.classList.remove('active'));
  el.classList.add('active');
  renderCatalog();
}

function switchTab(tab) {
  document.querySelectorAll('.nav-item').forEach(i => i.classList.remove('active'));
  document.querySelectorAll('.view-section').forEach(v => v.classList.add('hidden'));

  if (tab === 'catalog') {
    document.querySelector('.nav-item:nth-child(1)').classList.add('active');
    document.getElementById('view-catalog').classList.remove('hidden');
  } else if (tab === 'settings') {
    document.querySelector('.nav-item:nth-child(3)').classList.add('active');
    document.getElementById('view-settings').classList.remove('hidden');
  }
}

let currentEpisodeQualitiesMap = {};

function _epHasAnyLink(epNum) {
  const d = currentEpisodeQualitiesMap[epNum];
  if (!d) return false;
  return ['360p','480p','720p','1080p'].some(q => d[q] && d[q].trim() !== '');
}

function _epIsMissingLink(epNum) {
  const d = currentEpisodeQualitiesMap[epNum];
  if (!d) return false;
  // Has at least one link but not all 4
  const filled = ['360p','480p','720p','1080p'].filter(q => d[q] && d[q].trim() !== '').length;
  return filled > 0 && filled < 4;
}

function populateEpisodeSelectDropdown() {
  const totalEp = parseInt(document.getElementById("field-episodes").value) || 12;
  const select = document.getElementById("episode-select");
  const currentVal = select.value || 1;
  select.innerHTML = "";
  for (let i = 1; i <= totalEp; i++) {
    const opt = document.createElement("option");
    opt.value = i;
    const hasAll = _epHasAnyLink(i);
    const partial = _epIsMissingLink(i);
    // Visual markers: ✅ all filled, ⚠️ partial, nothing = empty
    if (hasAll && !partial) {
      opt.textContent = `✅ Eps ${i}`;
    } else if (partial) {
      opt.textContent = `⚠️ Eps ${i}`;
    } else {
      opt.textContent = `Eps ${i}`;
    }
    select.appendChild(opt);
  }
  // Restore previous selection if still valid
  if (currentVal && currentVal <= totalEp) {
    select.value = currentVal;
  }
  renderEpisodeQualityInputs();
  updateEpisodeProgressBar(totalEp);
}

function updateEpisodeProgressBar(totalEp) {
  const bar = document.getElementById("ep-progress-bar");
  const label = document.getElementById("ep-progress-label");
  if (!bar || !label) return;
  const filled = Array.from({length: totalEp}, (_, i) => i + 1).filter(i => _epHasAnyLink(i)).length;
  const pct = totalEp > 0 ? Math.round((filled / totalEp) * 100) : 0;
  bar.style.width = pct + "%";
  bar.style.background = pct === 100 ? "#2ed573" : pct > 50 ? "#00f2fe" : "#ff4757";
  label.textContent = `${filled}/${totalEp} episode terisi (${pct}%)`;
}

// Jump to episode by typing its number in the search box
function jumpToEpisodeSearch() {
  const searchInput = document.getElementById("episode-search");
  const num = parseInt(searchInput.value);
  const totalEp = parseInt(document.getElementById("field-episodes").value) || 12;
  if (!num || num < 1 || num > totalEp) {
    searchInput.style.borderColor = num ? "#ff4757" : "#00f2fe";
    return;
  }
  searchInput.style.borderColor = "#2ed573";
  // Save current before jumping
  saveCurrentEpisodeQualities();
  // Jump select to target episode
  const select = document.getElementById("episode-select");
  select.value = num;
  renderEpisodeQualityInputs();
  // Scroll option into view on the select
  select.scrollTop = (num - 1) * 20;
}

function renderEpisodeQualityInputs() {
  const currentEp = document.getElementById("episode-select").value || 1;
  const epData = currentEpisodeQualitiesMap[currentEp] || {};

  document.getElementById("link-360p").value = epData["360p"] || "";
  document.getElementById("link-480p").value = epData["480p"] || "";
  document.getElementById("link-720p").value = epData["720p"] || "";
  document.getElementById("link-1080p").value = epData["1080p"] || "";

  // Sync search box to current ep
  const searchBox = document.getElementById("episode-search");
  if (searchBox) {
    searchBox.value = currentEp;
    searchBox.style.borderColor = "#00f2fe";
  }

  // Update header indicator
  const header = document.getElementById("ep-current-label");
  if (header) header.textContent = `Episode ${currentEp}`;
}

function saveCurrentEpisodeQualities() {
  const currentEp = document.getElementById("episode-select").value || 1;
  currentEpisodeQualitiesMap[currentEp] = {
    "360p": document.getElementById("link-360p").value.trim(),
    "480p": document.getElementById("link-480p").value.trim(),
    "720p": document.getElementById("link-720p").value.trim(),
    "1080p": document.getElementById("link-1080p").value.trim(),
  };

  // Serialize to hidden field
  document.getElementById("field-watch").value = JSON.stringify(currentEpisodeQualitiesMap);

  // Refresh dropdown labels + progress bar
  const totalEp = parseInt(document.getElementById("field-episodes").value) || 12;
  populateEpisodeSelectDropdown();
  // Re-select current ep (populateEpisodeSelectDropdown resets it)
  document.getElementById("episode-select").value = currentEp;
  updateEpisodeProgressBar(totalEp);
}


// Modal Form Actions
function openAddModal() {
  document.getElementById("anime-id").value = "";
  document.getElementById("modal-title").textContent = "Tambah Anime Baru";
  document.getElementById("anime-form").reset();
  currentEpisodeQualitiesMap = {};
  // Reset placement to defaults
  document.querySelectorAll('input[name="placement"]').forEach(cb => {
    cb.checked = cb.value === 'explore';
  });
  populateEpisodeSelectDropdown();
  document.getElementById("anime-modal").classList.remove("hidden");
}

function closeAnimeModal() {
  document.getElementById("anime-modal").classList.add("hidden");
}

function editAnime(id) {
  const item = catalogData.find(x => x.id === id);
  if (!item) return;

  document.getElementById("anime-id").value = item.id;
  document.getElementById("modal-title").textContent = "Edit Anime: " + item.title;

  document.getElementById("field-title").value = item.title;
  document.getElementById("field-rating").value = item.rating || 8.0;
  document.getElementById("field-desc").value = item.description;
  document.getElementById("field-image").value = item.imageUrl;
  document.getElementById("field-trailer").value = item.trailerUrl || "";
  document.getElementById("field-watch").value = item.catalogEpisodeLink || "";
  document.getElementById("field-episodes").value = item.episodes || 12;
  document.getElementById("field-release-day").value = item.releaseDay || "";
  document.getElementById("field-status").value = item.status || "Ongoing";
  document.getElementById("field-genres").value = (item.genres || []).join(", ");
  document.getElementById("field-trending").checked = !!item.isTrending;

  try {
    currentEpisodeQualitiesMap = JSON.parse(item.catalogEpisodeLink || "{}");
  } catch (_) {
    currentEpisodeQualitiesMap = {};
  }

  // Restore placement checkboxes
  const savedPlacement = item.placement || ['explore'];
  document.querySelectorAll('input[name="placement"]').forEach(cb => {
    cb.checked = savedPlacement.includes(cb.value);
  });

  populateEpisodeSelectDropdown();
  document.getElementById("anime-modal").classList.remove("hidden");
}

function handleSaveAnime(e) {
  e.preventDefault();

  // Make custom- prefix so Flutter CatalogStore registers it as user entry
  let rawId = document.getElementById("anime-id").value;
  if (!rawId) {
    rawId = `custom-${Date.now()}`;
  } else if (!rawId.startsWith('custom-') && !rawId.startsWith('user-')) {
    rawId = `custom-${rawId}`;
  }

  const genresStr = document.getElementById("field-genres").value;
  const genresArr = genresStr.split(",").map(g => g.trim()).filter(g => g.length > 0);

  // Read placement checkboxes
  const placementChecks = document.querySelectorAll('input[name="placement"]:checked');
  let placement = Array.from(placementChecks).map(cb => cb.value);
  if (placement.length === 0) placement = ['explore']; // fallback

  // Auto-warn if jadwal selected but no releaseDay
  const releaseDayVal = document.getElementById("field-release-day").value;
  if (placement.includes('jadwal') && !releaseDayVal) {
    alert('⚠️ Kamu memilih tampilkan di Jadwal, tapi belum mengisi Hari Rilis!\nSilakan pilih hari rilis terlebih dahulu.');
    return;
  }

  const animeObj = {
    id: rawId,
    title: document.getElementById("field-title").value.trim(),
    rating: parseFloat(document.getElementById("field-rating").value) || 8.0,
    description: document.getElementById("field-desc").value.trim(),
    imageUrl: document.getElementById("field-image").value.trim(),
    trailerUrl: document.getElementById("field-trailer").value.trim() || null,
    catalogEpisodeLink: document.getElementById("field-watch").value.trim() || null,
    episodes: parseInt(document.getElementById("field-episodes").value) || 12,
    episodeCount: parseInt(document.getElementById("field-episodes").value) || 12,
    releaseDay: releaseDayVal ? parseInt(releaseDayVal) : null,
    status: document.getElementById("field-status").value || "Ongoing",
    genres: genresArr,
    isTrending: document.getElementById("field-trending").checked,
    placement: placement,
    addedAt: new Date().toISOString()
  };

  const existingIdx = catalogData.findIndex(x => x.id === rawId || x.id === document.getElementById("anime-id").value);
  if (existingIdx !== -1) {
    catalogData[existingIdx] = animeObj;
  } else {
    catalogData.unshift(animeObj);
  }

  saveCatalogData();
  closeAnimeModal();
}

function deleteAnime(id) {
  const item = catalogData.find(x => x.id === id);
  if (!item) return;

  if (confirm(`Apakah Anda yakin ingin menghapus "${item.title}" dari katalog?`)) {
    catalogData = catalogData.filter(x => x.id !== id);
    saveCatalogData();
  }
}

// Export JSON Data (Owner's full catalog)
function exportCatalogJSON() {
  // Only export entries added via this admin (custom- prefix)
  const toExport = catalogData.filter(x => x.id.startsWith('custom-'));
  const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(toExport, null, 2));
  const downloadAnchor = document.createElement('a');
  downloadAnchor.setAttribute("href", dataStr);
  downloadAnchor.setAttribute("download", `aniverse_catalog_${Date.now()}.json`);
  document.body.appendChild(downloadAnchor);
  downloadAnchor.click();
  downloadAnchor.remove();
}

// Export Template kosong untuk dikirim ke teman
function exportFriendTemplate() {
  const template = [
    {
      "id": "custom-GANTI_DENGAN_NAMA_ANIME",
      "title": "Nama Anime Di Sini",
      "imageUrl": "https://link-cover-image.jpg",
      "rating": 8.5,
      "genres": ["Action", "Fantasy"],
      "description": "Tulis sinopsis anime di sini...",
      "isTrending": false,
      "releaseDay": null,
      "episodeCount": 12,
      "episodes": 12,
      "trailerUrl": null,
      "catalogEpisodeLink": JSON.stringify({
        "1": { "360p": "https://link-ep1-360.mp4", "480p": "", "720p": "https://link-ep1-720.mp4", "1080p": "" }
      }),
      "addedAt": new Date().toISOString()
    }
  ];
  const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(template, null, 2));
  const a = document.createElement('a');
  a.setAttribute("href", dataStr);
  a.setAttribute("download", "aniverse_template_teman.json");
  document.body.appendChild(a);
  a.click();
  a.remove();
  alert("✅ Template berhasil diunduh!\nKirim file ini ke temanmu. Minta dia isi sesuai format, lalu kirim balik ke kamu.");
}

// Import JSON dari teman → merge deduplicated → langsung masuk Flutter via user_catalog_v1
function importCatalogJSON(event) {
  const file = event.target.files[0];
  if (!file) return;

  const reader = new FileReader();
  reader.onload = function(e) {
    try {
      const incoming = JSON.parse(e.target.result);
      if (!Array.isArray(incoming)) throw new Error("Format JSON tidak valid.");

      let addedCount = 0;
      let skippedCount = 0;

      incoming.forEach(item => {
        // Pastikan ID selalu punya prefix custom-
        if (!item.id) item.id = `custom-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
        if (!item.id.startsWith('custom-') && !item.id.startsWith('user-')) {
          item.id = `custom-${item.id}`;
        }

        const exists = catalogData.find(x => x.id === item.id || x.title.toLowerCase() === (item.title || '').toLowerCase());
        if (exists) {
          // Update data yang sudah ada dengan data dari teman (override jika ada yang baru)
          const idx = catalogData.indexOf(exists);
          catalogData[idx] = { ...exists, ...item, id: exists.id };
          skippedCount++;
        } else {
          catalogData.unshift(item);
          addedCount++;
        }
      });

      // Save ke localStorage agar Flutter app langsung bisa baca
      saveCatalogData();

      // Clear file input agar bisa import lagi
      event.target.value = '';

      alert(`✅ Import Berhasil!\n\n➕ Anime baru ditambahkan: ${addedCount}\n🔄 Anime diperbarui: ${skippedCount}\n\nData sudah tersimpan! Restart / Reload aplikasi AniVerse untuk melihat hasilnya.`);
    } catch (err) {
      alert(`❌ Import Gagal!\n\nPastikan file yang diimpor adalah file JSON yang valid dari AniVerse Admin.\n\nError: ${err.message}`);
    }
  };
  reader.readAsText(file);
}

function escapeHtml(str) {
  return (str || '').replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
