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
          ${item.trailerUrl ? '<span class="meta-pill" style="color:#00f2fe;">🎬 Trailer Ready</span>' : ''}
          ${item.catalogEpisodeLink ? '<span class="meta-pill" style="color:#2ed573;">▶ Stream Ready</span>' : ''}
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

// Modal Form Actions
function openAddModal() {
  document.getElementById("anime-id").value = "";
  document.getElementById("modal-title").textContent = "Tambah Anime Baru";
  document.getElementById("anime-form").reset();
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
  document.getElementById("field-genres").value = (item.genres || []).join(", ");
  document.getElementById("field-trending").checked = !!item.isTrending;

  document.getElementById("anime-modal").classList.remove("hidden");
}

function handleSaveAnime(e) {
  e.preventDefault();

  const id = document.getElementById("anime-id").value || `custom-${Date.now()}`;
  const genresStr = document.getElementById("field-genres").value;
  const genresArr = genresStr.split(",").map(g => g.trim()).filter(g => g.length > 0);

  const animeObj = {
    id: id,
    title: document.getElementById("field-title").value.trim(),
    rating: parseFloat(document.getElementById("field-rating").value) || 8.0,
    description: document.getElementById("field-desc").value.trim(),
    imageUrl: document.getElementById("field-image").value.trim(),
    trailerUrl: document.getElementById("field-trailer").value.trim() || null,
    catalogEpisodeLink: document.getElementById("field-watch").value.trim() || null,
    episodes: parseInt(document.getElementById("field-episodes").value) || 12,
    releaseDay: document.getElementById("field-release-day").value ? parseInt(document.getElementById("field-release-day").value) : null,
    genres: genresArr,
    isTrending: document.getElementById("field-trending").checked,
    addedAt: new Date().toISOString()
  };

  const existingIdx = catalogData.findIndex(x => x.id === id);
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

// Export JSON Data
function exportCatalogJSON() {
  const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(catalogData, null, 2));
  const downloadAnchor = document.createElement('a');
  downloadAnchor.setAttribute("href", dataStr);
  downloadAnchor.setAttribute("download", `aniverse_catalog_${Date.now()}.json`);
  document.body.appendChild(downloadAnchor);
  downloadAnchor.click();
  downloadAnchor.remove();
}

function escapeHtml(str) {
  return (str || '').replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
