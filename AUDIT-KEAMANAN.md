# Audit keamanan & privasi — Interflour HR (fork horilla-hr-mobile)

Basis: upstream `horilla/horilla-hr-mobile` commit `ae33dbf` (v2.0.0+17, Flutter, LGPL-2.1).
Fork: `com.satriaweb.interflourhr`, server bawaan `https://hr.satri.duckdns.org`.

## Temuan dan tindakan

| # | Tingkat | Temuan | Tindakan di fork |
|---|---|---|---|
| 1 | **Tinggi** | Alamat server bawaan = server demo publik `hr.demo.horilla.com`. Karyawan yang langsung login tanpa mengganti alamat mengirim username + password aslinya ke server pihak lain. | Bawaan diganti `https://hr.satri.duckdns.org`. |
| 2 | Sedang | GPS hanya dikirim bila server melaporkan satu geofence (pusat + radius). Karyawan yang memakai **Grup Lokasi** (banyak titik) tidak mengirim GPS → server menolak absen. | Aplikasi membaca daftar `points`, selalu mengirim GPS bila geofence aktif, dan memeriksa titik yang memuat posisi / terdekat. Server (Horilla cabang satria) mengirim `points`. |
| 3 | Sedang | `allowBackup` bawaan aktif: data aplikasi (shared_preferences: alamat server, preferensi) ikut cadangan Google/adb. Token sudah di Keystore (aman). | `allowBackup="false"`, `fullBackupContent="false"`. |
| 4 | Sedang | **Google ML Kit face detection** (deteksi wajah di perangkat). Gambar tidak dikirim, tetapi SDK ML Kit mengirim metrik pemakaian/performa API ke Google. Dipakai hanya bila fitur Face Detection di server aktif (Interflour: belum). | **Belum diubah di rilis ini** (rilis kecil, satu perubahan berisiko per rilis). Usulan rilis berikut: buang ML Kit + gerbang wajah bila Face Detection tidak dipakai. |
| 5 | Rendah | Lima pustaka ML Kit text-recognition (Latin/Cina/Devanagari/Jepang/Korea) dimuat padahal tidak dipakai di kode Dart — ukuran APK + kode Google tambahan. | Dibuang. |
| 6 | Rendah | Izin `READ/WRITE_EXTERNAL_STORAGE` tidak dipakai; izin `ACCESS_NETWORK-STATE` salah ketik (tidak berlaku). | Izin penyimpanan dibuang; nama izin diperbaiki. |
| 6b | Rendah | Plugin kamera menggabungkan izin `RECORD_AUDIO` dan izin penyimpanan ke manifest akhir, padahal kamera selalu dibuka `enableAudio: false` dan foto masuk cache aplikasi. | mi2: dibuang dengan `tools:node="remove"`. |
| 7 | Info | Release tanpa `signingConfig` di repo. | Dipertahankan: APK dibangun tanpa tanda tangan di GitHub Actions, ditandatangani di server (kunci tidak pernah di GitHub). |

## Perubahan fitur
- **mi5 — Foto absen.** Gerbang deteksi wajah otomatis (ML Kit) tidak pernah lolos di Samsung S24 Ultra dan tidak punya tombol. Diganti layar kamera dengan tombol *Take photo* → *Use photo*; foto dikirim bersama absen (multipart `photo` + koordinat) dan disimpan server (tanpa EXIF) untuk diperiksa HR. Muncul bila server mewajibkan foto (`punch_photo.required`) atau Face Detection aktif. Catatan: deteksi wajah Horilla tidak pernah mencocokkan identitas (hanya "ada wajah").

## Yang sudah baik (tidak diubah)
- Tidak ada Firebase / analytics / crash reporter / iklan (dicek di `pubspec.lock` dan konfigurasi Android).
- Token login di Keystore (`flutter_secure_storage`), bukan shared_preferences.
- `http://` hanya diizinkan untuk alamat privat (LAN / `.local`); semua host lain wajib HTTPS.
- Tidak ada log token / isi respons di build release.
- Biometrik hanya sebagai kunci masuk ulang, bukan faktor login.
- Server tetap otoritas geofence (aplikasi hanya memberi tahu lebih awal).

## Belum diuji
APK tidak bisa dijalankan dari server; pengujian di perangkat dilakukan di HP.
