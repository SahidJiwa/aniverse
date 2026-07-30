/**
 * Migrasi catalog_cloud.json -> Firestore koleksi "anime"
 * -------------------------------------------------------
 * Cara pakai:
 * 1. npm install firebase-admin
 * 2. Taruh file service-account-key.json (dari Firebase Console > Project Settings > Service accounts) di folder ini
 * 3. Taruh catalog_cloud.json di folder ini juga
 * 4. Jalankan: node migrate_to_firestore.js
 */

const admin = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const fs = require("fs");
const path = require("path");

const serviceAccount = require("./service-account-key.json");

admin.initializeApp({
  credential: admin.cert(serviceAccount)
});

const db = getFirestore();

async function migrate() {
  const jsonPath = path.join(__dirname, "catalog_cloud.json");
  if (!fs.existsSync(jsonPath)) {
    console.error("catalog_cloud.json tidak ditemukan di folder ini.");
    process.exit(1);
  }

  const catalog = JSON.parse(fs.readFileSync(jsonPath, "utf-8"));
  if (!Array.isArray(catalog)) {
    console.error("Format catalog_cloud.json harus array.");
    process.exit(1);
  }

  console.log(`Ditemukan ${catalog.length} anime. Mulai migrasi ke Firestore...`);

  const batchSize = 400; // Firestore batch limit 500, kita kasih margin
  let count = 0;

  for (let i = 0; i < catalog.length; i += batchSize) {
    const batch = db.batch();
    const chunk = catalog.slice(i, i + batchSize);

    chunk.forEach(anime => {
      if (!anime.id) {
        console.warn("Anime tanpa id dilewati:", anime.title);
        return;
      }
      const docRef = db.collection("anime").doc(anime.id);
      batch.set(docRef, anime, { merge: true });
      count++;
    });

    await batch.commit();
    console.log(`Batch ${Math.floor(i / batchSize) + 1} selesai (${count} dokumen tertulis sejauh ini)`);
  }

  console.log(`✅ Migrasi selesai. Total ${count} anime masuk ke koleksi "anime" di Firestore.`);
  process.exit(0);
}

migrate().catch(err => {
  console.error("❌ Migrasi gagal:", err);
  process.exit(1);
});
