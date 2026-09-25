import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import parse_xml, OxmlElement
from docx.oxml.ns import nsdecls, qn

doc = docx.Document()

# Page Margins
for section in doc.sections:
    section.top_margin = Inches(1)
    section.bottom_margin = Inches(1)
    section.left_margin = Inches(1)
    section.right_margin = Inches(1)

# Base Style
style = doc.styles['Normal']
font = style.font
font.name = 'Arial'
font.size = Pt(10.5)
font.color.rgb = RGBColor(0x22, 0x22, 0x22)

def set_cell_bg(cell, fill_hex):
    tcPr = cell._element.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    tcPr.append(shd)

def set_table_borders(table):
    tblPr = table._element.xpath('w:tblPr')
    if tblPr:
        borders = parse_xml(
            f'<w:tblBorders {nsdecls("w")}>\n'
            f'  <w:top w:val="single" w:sz="4" w:space="0" w:color="DDE7F2"/>\n'
            f'  <w:bottom w:val="single" w:sz="4" w:space="0" w:color="DDE7F2"/>\n'
            f'  <w:left w:val="none"/>\n'
            f'  <w:right w:val="none"/>\n'
            f'  <w:insideH w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>\n'
            f'  <w:insideV w:val="none"/>\n'
            f'</w:tblBorders>'
        )
        tblPr[0].append(borders)

def add_title(text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run(text)
    run.font.size = Pt(18)
    run.font.bold = True
    run.font.color.rgb = RGBColor(0x00, 0x6D, 0x9E)
    p.paragraph_format.space_after = Pt(4)

def add_subtitle(text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run(text)
    run.font.size = Pt(13)
    run.font.bold = True
    run.font.color.rgb = RGBColor(0x34, 0x5A, 0x85)
    p.paragraph_format.space_after = Pt(18)

def add_h1(text):
    p = doc.add_paragraph()
    run = p.add_run(text)
    run.font.size = Pt(13)
    run.font.bold = True
    run.font.color.rgb = RGBColor(0x00, 0x6D, 0x9E)
    p.paragraph_format.space_before = Pt(14)
    p.paragraph_format.space_after = Pt(4)

def add_h2(text):
    p = doc.add_paragraph()
    run = p.add_run(text)
    run.font.size = Pt(11.5)
    run.font.bold = True
    run.font.color.rgb = RGBColor(0x0D, 0x1F, 0x44)
    p.paragraph_format.space_before = Pt(10)
    p.paragraph_format.space_after = Pt(3)

def add_p(text, bold_prefix="", italic_prefix=""):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.line_spacing = 1.15
    if bold_prefix:
        r_b = p.add_run(bold_prefix)
        r_b.bold = True
    if italic_prefix:
        r_i = p.add_run(italic_prefix)
        r_i.italic = True
    p.add_run(text)
    return p

def add_bullet(text, bold_prefix=""):
    p = doc.add_paragraph(style='List Bullet')
    p.paragraph_format.space_after = Pt(3)
    p.paragraph_format.line_spacing = 1.15
    if bold_prefix:
        r_b = p.add_run(bold_prefix)
        r_b.bold = True
    p.add_run(text)
    return p

# --- HEADER / TITLE ---
add_title("DOKUMENTASI PROJECT KELOMPOK")
add_subtitle("Aplikasi AturAja (Manajemen Keuangan & Tugas Mahasiswa)")

# Info Box Table
t_info = doc.add_table(rows=4, cols=2)
t_info.alignment = WD_TABLE_ALIGNMENT.CENTER
info_data = [
    ("Aplikasi", "AturAja — Productivity & Financial Assistant"),
    ("Mata Kuliah", "Pemrograman Mobile"),
    ("Kelompok", "Kelompok AturAja"),
    ("Anggota Kelompok", "1. M Zidan Ruriano AG (NIM: 241401063)\n2. [Nama Anggota 2] (NIM: [NIM 2])\n3. [Nama Anggota 3] (NIM: [NIM 3])")
]
for i, (k, v) in enumerate(info_data):
    r = t_info.rows[i]
    r.cells[0].paragraphs[0].add_run(k).bold = True
    r.cells[1].paragraphs[0].add_run(v)
    set_cell_bg(r.cells[0], "EEF2F7")
set_table_borders(t_info)

doc.add_paragraph().paragraph_format.space_after = Pt(12)

# --- 1. PERSONA UTAMA ---
add_h1("1. PERSONA UTAMA")

add_h2("1.1 Identitas Persona")
add_bullet("Budi Pratama", "Nama Persona: ")
add_bullet("Mahasiswa Rantau Teknik Informatika USU (Semester 5)", "Status/Peran: ")
add_bullet("Mengatur jadwal tugas perkuliahan, urusan harian (laundry, olahraga, keuangan), dan anggaran bulanan secara seimbang agar tidak menumpuk dan tidak boros.", "Tujuan Utama: ")

add_p("Kebutuhan Utama Persona:")
add_bullet("Pencatatan tugas perkuliahan & kegiatan harian dengan pengelompokan multi-kategori (Tugas Kuliah, Laundry, Olahraga, Keuangan, Organisasi, dll).", "1. ")
add_bullet("Peringatan otomatis untuk tugas mendesak (< 24 jam) dan penanda tugas terlewat (Overdue) agar terhindar dari keterlambatan pengumpulan.", "2. ")
add_bullet("Input cepat berbasis AI (AI Brain Dump) untuk memilah tugas, jadwal, atau pengeluaran hanya dari satu kalimat penjelasan bebas.", "3. ")

add_p("Masalah yang Dihadapi Persona:")
add_bullet("Sering lupa deadline tugas perkuliahan yang saling berdekatan akibat banyaknya kesibukan harian.", "1. ")
add_bullet("Merasa malas jika harus mengisi form tugas yang rumit satu per satu saat kondisi lelah.", "2. ")
add_bullet("Kesulitan memisahkan dan memprioritaskan tugas akademis dengan urusan kebutuhan pribadi/kos.", "3. ")

add_h2("1.2 Tujuan Penggunaan Aplikasi")
add_p("Aplikasi AturAja membantu Budi mengelola produktivitas akademik dan gaya hidup harian secara terintegrasi, responsif, dan terorganisir dalam satu aplikasi mobile. Dengan fitur AI Brain Dump dan kalkulasi deadline otomatis, Budi dapat mencatat dan memantau seluruh kewajibannya tanpa rasa cemas.")

# --- 2. SCREEN MAP ---
add_h1("2. SCREEN MAP")

add_h2("2.1 Daftar Screen (10 Screen Fungsional)")
headers = ["No", "Nama Screen", "Fungsi Utama"]
screens = [
    ("1", "SplashScreen", "Tampilan animasi loading awal aplikasi dan inisialisasi tema."),
    ("2", "MainShell", "Shell navigasi utama dengan bottom navigation bar untuk berpindah antar-tab."),
    ("3", "HomeScreen", "Dashboard ringkasan tugas hari ini, kondisi keuangan, dan quick action."),
    ("4", "TaskScreen", "Halaman utama manajemen tugas dengan progress minggu ini dan dropdown filter."),
    ("5", "TaskDetailScreen", "Halaman detail tugas full screen (judul, status, multi-kategori, deadline, deskripsi)."),
    ("6", "TaskFormScreen", "Halaman form tambah & edit tugas full screen (dukungan Form Manual & AI Brain Dump)."),
    ("7", "FinanceScreen", "Halaman manajemen keuangan, riwayat transaksi pengeluaran, dan pemasokan."),
    ("8", "ProfileScreen", "Halaman profil pengguna, statistik tugas selesai, dan tombol toggle tema Dark/Light."),
    ("9", "ScanScreen", "Halaman pemindai kuitansi/struk belanja menggunakan kamera device."),
    ("10", "QuickAddModal", "Bottom sheet modal pencatatan cepat / brain dump global.")
]

t_scr = doc.add_table(rows=len(screens)+1, cols=3)
for col_idx, h in enumerate(headers):
    c = t_scr.rows[0].cells[col_idx]
    c.paragraphs[0].add_run(h).bold = True
    set_cell_bg(c, "006D9E")
    c.paragraphs[0].runs[0].font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

for row_idx, row_data in enumerate(screens):
    r = t_scr.rows[row_idx+1]
    for col_idx, val in enumerate(row_data):
        r.cells[col_idx].paragraphs[0].add_run(val)
        if row_idx % 2 == 1:
            set_cell_bg(r.cells[col_idx], "F8FAFC")
set_table_borders(t_scr)

add_h2("2.2 Diagram Navigasi")
add_p("AturAja Navigasi Tree:\n"
      "MainShell (Bottom Navigation Bar)\n"
      " ├── HomeScreen (Dashboard Utama)\n"
      " │    ├── QuickAddModal (Bottom Sheet Brain Dump Global)\n"
      " │    └── ScanScreen (Pemindai Kamera Struk)\n"
      " ├── TaskScreen (Manajemen Tugas)\n"
      " │    ├── TaskDetailScreen (Full Screen Detail Tugas & Action Status)\n"
      " │    └── TaskFormScreen (Full Screen Form Tambah/Edit Tugas & AI Brain Dump)\n"
      " ├── FinanceScreen (Manajemen Keuangan)\n"
      " └── ProfileScreen (Profil & Toggle Tema Dark/Light)")

# --- 3. USER FLOW ---
add_h1("3. USER FLOW")

add_h2("3.1 User Flow 1: Menambah Tugas Baru via Form Manual & AI Brain Dump")
add_bullet("Membuat tugas baru dengan pengelompokan multi-kategori dan kalkulasi deadline otomatis.", "Tujuan: ")
add_bullet("HomeScreen / TaskScreen → Klik + Tambah → TaskFormScreen (Pilih Mode Manual / AI Brain Dump) → Input Data / Tulis Brain Dump → Validasi Form → Klik 'Tambah Tugas' → TaskScreen.", "Urutan: ")
add_bullet("Tugas baru tersimpan di state memori, pesan SnackBar konfirmasi muncul, dan daftar tugas ter-refresh otomatis.", "Hasil Akhir: ")

add_h2("3.2 User Flow 2: Meninjau Detail Tugas & Menandai Selesai / Edit")
add_bullet("Melihat informasi rinci tugas dan memperbarui status penyelesaiannya.", "Tujuan: ")
add_bullet("TaskScreen → Klik Kartu Tugas → TaskDetailScreen → Tinjau Kategori & Deskripsi → Klik 'Tandai Selesai' / 'Edit' → TaskScreen.", "Urutan: ")
add_bullet("Status tugas terupdate di state, indikator centang hijau aktif, dan persentase progress minggu ini bertambah.", "Hasil Akhir: ")

add_h2("3.3 User Flow 3: Menyaring Tugas Berdasarkan Status & Multi-Kategori")
add_bullet("Memfilter tampilan daftar tugas menggunakan dropdown status dan dropdown kategori.", "Tujuan: ")
add_bullet("TaskScreen → Klik Dropdown Status (Belum Selesai/Mendesak/Selesai) → Klik Dropdown Kategori (Tugas Kuliah/Laundry/dll) → Daftar Tugas Ter-filter Real-time.", "Urutan: ")
add_bullet("Daftar tugas menampilkan data yang sesuai dengan kombinasi filter atau menampilkan AppEmptyState yang rapi jika tidak ada data.", "Hasil Akhir: ")

# --- 4. MODEL DATA ---
add_h1("4. MODEL DATA")

add_h2("4.1 Model TaskItem (Modul Utama Tugas)")
t_model1 = doc.add_table(rows=8, cols=3)
m1_headers = ["Field", "Tipe Data", "Keterangan"]
m1_data = [
    ("id", "int", "ID unik tugas (milidetik timestamp / integer)"),
    ("title", "String", "Judul utama tugas (Minimal 4 - Maksimal 100 karakter)"),
    ("categories", "List<String>", "Daftar multi-kategori tugas (Tugas Kuliah, Laundry, Olahraga, dll)"),
    ("description", "String", "Deskripsi detail atau catatan instruksi tugas (Maksimal 500 karakter)"),
    ("deadline", "String", "Teks deskripsi tenggat waktu manusia (misal: 'Besok, 08:00')"),
    ("dueDate", "DateTime?", "Objek tanggal & jam tenggat waktu untuk kalkulasi otomatis"),
    ("done", "bool", "Status penyelesaian tugas (true = selesai, false = belum)")
]
for col_idx, h in enumerate(m1_headers):
    c = t_model1.rows[0].cells[col_idx]
    c.paragraphs[0].add_run(h).bold = True
    set_cell_bg(c, "006D9E")
    c.paragraphs[0].runs[0].font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

for row_idx, row_data in enumerate(m1_data):
    r = t_model1.rows[row_idx+1]
    for col_idx, val in enumerate(row_data):
        r.cells[col_idx].paragraphs[0].add_run(val)
set_table_borders(t_model1)

add_p("Getter Method Tambahan pada TaskItem:")
add_bullet("isOverdue (bool): Kalkulasi otomatis apakah dueDate < DateTime.now() dan done == false.", "● ")
add_bullet("urgent (bool): Kalkulasi otomatis apakah sisa waktu dueDate < 24 jam dan done == false.", "● ")

add_h2("4.2 Model TransactionItem (Modul Keuangan)")
t_model2 = doc.add_table(rows=7, cols=3)
m2_data = [
    ("id", "int", "ID unik transaksi"),
    ("label", "String", "Deskripsi/nama transaksi pengeluaran atau pemasukan"),
    ("amount", "int", "Nominal transaksi (negatif = pengeluaran, positif = pemasukan)"),
    ("cat", "String", "Kategori transaksi (food, entertainment, income, dll)"),
    ("time", "String", "Waktu transaksi (HH:mm)"),
    ("consumtive", "bool", "Indikator pengeluaran konsumtif")
]
for col_idx, h in enumerate(m1_headers):
    c = t_model2.rows[0].cells[col_idx]
    c.paragraphs[0].add_run(h).bold = True
    set_cell_bg(c, "006D9E")
    c.paragraphs[0].runs[0].font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

for row_idx, row_data in enumerate(m2_data):
    r = t_model2.rows[row_idx+1]
    for col_idx, val in enumerate(row_data):
        r.cells[col_idx].paragraphs[0].add_run(val)
set_table_borders(t_model2)

add_h2("4.3 Model Referensi Kategori (availableCategories)")
add_p("Tersedia 7 kategori referensi kegiatan mahasiswa:\n"
      "1. Tugas Kuliah  2. Pribadi  3. Laundry  4. Olahraga  5. Organisasi  6. Keuangan  7. Lainnya")

add_h2("4.4 Hubungan Antar-Data")
add_p("Setiap TaskItem menyimpan atribut `categories` berupa List<String> yang mereferensikan satu atau lebih nama dari `availableCategories`. Hal ini memungkinkan relasi multi-kategori (Many-to-Many) antara tugas dan kategori secara fleksibel.")

# --- 5. MODUL CRUD ---
add_h1("5. MODUL CRUD")

add_h2("5.1 Modul CRUD 1: Manajemen Tugas (TaskItem)")
t_crud1 = doc.add_table(rows=5, cols=3)
c_headers = ["Operasi", "Implementasi", "Cara Kerja & Keterangan"]
c_data = [
    ("Create", "Ya", "Melalui TaskFormScreen (Form Manual & AI Brain Dump). Menginsert TaskItem baru ke daftar state memori."),
    ("Read", "Ya", "Melalui TaskScreen (Daftar ter-filter) dan TaskDetailScreen (Layar penuh detail tugas)."),
    ("Update", "Ya", "Edit data tugas di TaskFormScreen atau toggle status selesai di TaskScreen / TaskDetailScreen."),
    ("Delete", "Ya", "Hapus tugas dengan konfirmasi AlertDialog di TaskDetailScreen atau dialog konfirmasi.")
]
for col_idx, h in enumerate(c_headers):
    c = t_crud1.rows[0].cells[col_idx]
    c.paragraphs[0].add_run(h).bold = True
    set_cell_bg(c, "006D9E")
    c.paragraphs[0].runs[0].font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

for row_idx, row_data in enumerate(c_data):
    r = t_crud1.rows[row_idx+1]
    for col_idx, val in enumerate(row_data):
        r.cells[col_idx].paragraphs[0].add_run(val)
set_table_borders(t_crud1)

add_h2("5.2 Modul CRUD 2: Manajemen Keuangan (TransactionItem)")
t_crud2 = doc.add_table(rows=5, cols=3)
c2_data = [
    ("Create", "Ya", "Pencatatan cepat pengeluaran/pemasukan melalui QuickAddModal."),
    ("Read", "Ya", "Tampilan daftar riwayat transaksi pada FinanceScreen."),
    ("Update", "Ya", "Perubahan data transaksi pada riwayat keuangan."),
    ("Delete", "Ya", "Penghapusan catatan transaksi dari riwayat.")
]
for col_idx, h in enumerate(c_headers):
    c = t_crud2.rows[0].cells[col_idx]
    c.paragraphs[0].add_run(h).bold = True
    set_cell_bg(c, "006D9E")
    c.paragraphs[0].runs[0].font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

for row_idx, row_data in enumerate(c2_data):
    r = t_crud2.rows[row_idx+1]
    for col_idx, val in enumerate(row_data):
        r.cells[col_idx].paragraphs[0].add_run(val)
set_table_borders(t_crud2)

# --- 6. DATA SIMULASI ---
add_h1("6. DATA SIMULASI")

add_h2("6.1 Data Utama (20 Record SIMULASI)")
add_p("Tersedia 10 Record Tugas (TaskItem) dan 10 Record Keuangan (TransactionItem):")

t_sim = doc.add_table(rows=11, cols=4)
sim_headers = ["ID", "Judul / Label", "Kategori", "Status / Nominal"]
sim_data = [
    ("1", "Laporan Praktikum Pemrograman Web (Modul 5)", "Tugas Kuliah", "Mendesak (<24j)"),
    ("2", "Quiz Bab 4 Probabilitas & Statistik", "Tugas Kuliah, Pribadi", "Mendesak (<24j)"),
    ("3", "Ambil Laundry Sehari Selesai & Cuci Sepatu", "Laundry, Pribadi", "Mendesak (<24j)"),
    ("4", "Latihan Routine Calisthenics & Jogging 5KM", "Olahraga, Pribadi", "Belum Selesai"),
    ("5", "Bayar Uang Kos Bulan Ini & Token Listrik PLN", "Keuangan, Pribadi", "Belum Selesai"),
    ("6", "Rapat Pleno BEM & Penyusunan Proposal Event", "Organisasi, Tugas Kuliah", "Belum Selesai"),
    ("7", "Belanja Sembako & Meal Prep Mingguan Hemat", "Pribadi, Keuangan", "Belum Selesai"),
    ("8", "Riset Topik Skripsi & Review 3 Jurnal SINTA 2", "Tugas Kuliah, Pribadi", "Belum Selesai"),
    ("9", "Diskusi Kelompok Makalah Kewirausahaan Digital", "Tugas Kuliah, Organisasi", "Selesai 🎉"),
    ("10", "Pengisian Form KRS & Verifikasi Dosen Pembimbing", "Tugas Kuliah, Keuangan", "Selesai 🎉")
]
for col_idx, h in enumerate(sim_headers):
    c = t_sim.rows[0].cells[col_idx]
    c.paragraphs[0].add_run(h).bold = True
    set_cell_bg(c, "006D9E")
    c.paragraphs[0].runs[0].font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

for row_idx, row_data in enumerate(sim_data):
    r = t_sim.rows[row_idx+1]
    for col_idx, val in enumerate(row_data):
        r.cells[col_idx].paragraphs[0].add_run(val)
set_table_borders(t_sim)

add_h2("6.2 Data Referensi / Kategori (7 Record)")
add_p("Data referensi kategori: 1. Tugas Kuliah, 2. Pribadi, 3. Laundry, 4. Olahraga, 5. Organisasi, 6. Keuangan, 7. Lainnya.")

# --- 7. STATE DAN NAVIGASI ---
add_h1("7. STATE DAN NAVIGASI")

add_h2("7.1 State Management")
add_bullet("StatefulWidget & setState() untuk reactivity lokal real-time.", "State Management: ")
add_bullet("ThemeScope (InheritedWidget) untuk mengelola mode tema Dark/Light secara terpusat.", "Theme Controller: ")
add_bullet("Reactivity, Unidirectional Data Flow, dan Sync UI real-time saat data tugas ditambah/diubah/dihapus.", "Prinsip: ")

add_h2("7.2 Navigasi")
add_bullet("Menggunakan Navigator.of(context).push(MaterialPageRoute(...)) untuk membuka halaman full screen TaskDetailScreen dan TaskFormScreen.", "Navigasi Layar: ")
add_bullet("Menggunakan showDialog() untuk konfirmasi hapus data dan showModalBottomSheet() untuk quick add.", "Dialog & Modal: ")

# --- 8. KONDISI KHUSUS UI ---
add_h1("8. KONDISI KHUSUS UI")

add_bullet("CircularProgressIndicator & AppProcessingState ditampilkan saat AI Brain Dump memproses teks masukan pengguna.", "8.1 Loading State: ")
add_bullet("AppEmptyState dengan width: double.infinity dan pesan kontekstual ketika daftar tugas kosong atau filter tidak menemukan hasil.", "8.2 Empty State: ")
add_bullet("AppErrorMessage dengan banner merah dan pesan validasi spesifik saat input tidak memenuhi syarat.", "8.3 Error State: ")
add_bullet("Tombol Reset Filter (🔄) untuk mengembalikan filter ke kondisi awal dan tombol pemicu ulang proses AI Brain Dump.", "8.4 Retry: ")
add_bullet("Floating SnackBar dengan sudut rounded (16px), border aksen, dan ikon sukses saat operasi berhasil.", "8.5 Success State: ")

# --- 9. VALIDASI FORM ---
add_h1("9. VALIDASI FORM")

t_val = doc.add_table(rows=6, cols=4)
v_headers = ["Field", "Jenis Input", "Aturan Validasi", "Pesan Error"]
v_data = [
    ("Judul Tugas", "TextField", "Wajib diisi, Minimal 4 - Maksimal 100 karakter", "Judul tugas terlalu pendek (minimal 4 karakter)"),
    ("Kategori", "Multi-Select Dropdown", "Wajib memilih minimal 1 kategori", "Pilih minimal 1 kategori untuk tugas ini!"),
    ("Tenggat Waktu", "TextField + Date/Time Picker", "Wajib diisi / terpilih", "Tenggat waktu tidak boleh kosong."),
    ("Deskripsi Detail", "TextField Multiline", "Maksimal 500 karakter", "Karakter melebihi batas 500 karakter"),
    ("AI Brain Dump", "TextField Multiline", "Minimal 5 karakter", "Isi brain dump terlalu pendek (minimal 5 karakter)")
]
for col_idx, h in enumerate(v_headers):
    c = t_val.rows[0].cells[col_idx]
    c.paragraphs[0].add_run(h).bold = True
    set_cell_bg(c, "006D9E")
    c.paragraphs[0].runs[0].font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

for row_idx, row_data in enumerate(v_data):
    r = t_val.rows[row_idx+1]
    for col_idx, val in enumerate(row_data):
        r.cells[col_idx].paragraphs[0].add_run(val)
set_table_borders(t_val)

# --- 10. PEMBAGIAN KONTRIBUSI ANGGOTA ---
add_h1("10. PEMBAGIAN KONTRIBUSI ANGGOTA")

t_kontrib = doc.add_table(rows=4, cols=3)
k_headers = ["Anggota", "Fitur / Tanggung Jawab Utama", "Bagian yang Dikerjakan"]
k_data = [
    ("M Zidan Ruriano AG (NIM: 241401063)", "Modul Utama Manajemen Tugas & AI Brain Dump", "Model TaskItem, UI TaskScreen, TaskDetailScreen, TaskFormScreen, Multi-Select Dropdown Kategori, Dropdown Filter Bar, Status Handling (Overdue/Urgent <24j), Validasi Form, UI Polish & Theme Consistency."),
    ("[Nama Anggota 1] (NIM: [NIM 1])", "Modul Keuangan & Transaksi", "Model TransactionItem, UI FinanceScreen, QuickAddModal, Grafik Keuangan."),
    ("[Nama Anggota 2] (NIM: [NIM 2])", "Modul Profil, Struk Scanner, & Navigation Shell", "UI ProfileScreen, ScanScreen, SplashScreen, MainShell Navigation.")
]
for col_idx, h in enumerate(k_headers):
    c = t_kontrib.rows[0].cells[col_idx]
    c.paragraphs[0].add_run(h).bold = True
    set_cell_bg(c, "006D9E")
    c.paragraphs[0].runs[0].font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

for row_idx, row_data in enumerate(k_data):
    r = t_kontrib.rows[row_idx+1]
    for col_idx, val in enumerate(row_data):
        r.cells[col_idx].paragraphs[0].add_run(val)
set_table_borders(t_kontrib)

# --- 11. MATRIKS PENGUJIAN (20 SKENARIO) ---
add_h1("11. MATRIKS PENGUJIAN (20 SKENARIO)")

t_test = doc.add_table(rows=21, cols=5)
t_headers = ["No", "Skenario Pengujian", "Langkah / Input", "Expected Result", "Status"]
t_data = [
    ("1", "Tambah tugas valid (Manual)", "Isi judul valid, pilih kategori, pilih tanggal, klik Tambah", "Tugas baru tersimpan dan SnackBar sukses muncul", "Pass"),
    ("2", "Tambah tugas via AI Brain Dump", "Tulis 'Quiz kalkulus besok jam 08:00', klik Proses", "AI memilah judul, kategori, dan deadline otomatis", "Pass"),
    ("3", "Validasi judul pendek (< 4 char)", "Input judul 'abc', klik Tambah", "AppErrorMessage muncul: Judul terlalu pendek", "Pass"),
    ("4", "Validasi kategori kosong", "Hapus semua kategori terpilih pada form", "AppErrorMessage muncul: Pilih minimal 1 kategori", "Pass"),
    ("5", "Edit tugas", "Buka detail → Edit → Ubah judul & deskripsi → Simpan", "Data tugas ter-update di daftar dan detail", "Pass"),
    ("6", "Batal edit tugas", "Buka form edit → Tekan ikon X / Batal", "Perubahan dibatalkan, kembali ke layar sebelumnya", "Pass"),
    ("7", "Hapus tugas dengan konfirmasi", "Buka detail → Hapus → Klik 'Hapus' pada AlertDialog", "Tugas terhapus dari state dan SnackBar merah muncul", "Pass"),
    ("8", "Batal hapus tugas", "Buka detail → Hapus → Klik 'Batal' pada AlertDialog", "Dialog tertutup, tugas tidak terhapus", "Pass"),
    ("9", "Toggle status selesai (Checkbox)", "Klik checkbox pada kartu tugas", "Status berganti selesai, garis dicoret, progress naik", "Pass"),
    ("10", "Toggle status buka kembali", "Klik checkbox pada tugas yang sudah selesai", "Status kembali belum selesai, progress ter-update", "Pass"),
    ("11", "Filter status (Mendesak <24j)", "Pilih Dropdown Status = 'Mendesak <24j'", "Hanya menampilkan tugas dengan deadline < 24 jam", "Pass"),
    ("12", "Filter kategori (Tugas Kuliah)", "Pilih Dropdown Kategori = 'Tugas Kuliah'", "Hanya menampilkan tugas berkategori 'Tugas Kuliah'", "Pass"),
    ("13", "Reset Filter", "Klik tombol 🔄 pada filter bar", "Filter kembali ke Semua Status & Semua Kategori", "Pass"),
    ("14", "Filter data kosong", "Pilih kombinasi filter tanpa data matching", "AppEmptyState selebar layar (width: double.infinity) muncul", "Pass"),
    ("15", "Kalkulasi otomatis status Mendesak", "Set deadline tugas kurang dari 24 jam", "Badge 🔥 Mendesak (<24j) dan titik kuning muncul", "Pass"),
    ("16", "Kalkulasi otomatis status Overdue", "Set deadline tugas ke tanggal yang sudah lewat", "Badge ⚠️ Terlewat dan titik merah muncul", "Pass"),
    ("17", "Toggle Tema Dark / Light", "Klik tombol switch tema di header", "Warna seluruh UI (AppColors) berganti instant", "Pass"),
    ("18", "Navigasi Layar Penuh (Detail/Form)", "Klik kartu tugas / tombol Tambah", "Layar transisi ke full-screen Scaffold tanpa glitch", "Pass"),
    ("19", "Double submit prevention", "Klik tombol Tambah secara berulang cepat", "Hanya 1 proses submit yang dieksekusi", "Pass"),
    ("20", "Uji Responsif & Teks Panjang", "Input judul & deskripsi 500 karakter", "UI menyesuaikan tanpa overflow/clipping", "Pass")
]
for col_idx, h in enumerate(t_headers):
    c = t_test.rows[0].cells[col_idx]
    c.paragraphs[0].add_run(h).bold = True
    set_cell_bg(c, "006D9E")
    c.paragraphs[0].runs[0].font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

for row_idx, row_data in enumerate(t_data):
    r = t_test.rows[row_idx+1]
    for col_idx, val in enumerate(row_data):
        r.cells[col_idx].paragraphs[0].add_run(val)
set_table_borders(t_test)

# --- 12. KETERBATASAN APLIKASI ---
add_h1("12. KETERBATASAN APLIKASI")
add_bullet("Penyimpanan data masih berbasis in-memory/simulasi lokal (belum terhubung ke database cloud Firebase/REST API).", "● ")
add_bullet("Data riset akan kembali ke kondisi data sampel default jika aplikasi di-restart total.", "● ")
add_bullet("Proses AI Brain Dump menggunakan pustaka parser aturan heuristik lokal (simulasi AI).", "● ")

# --- 13. CHECKLIST SEBELUM UTS ---
add_h1("13. CHECKLIST SEBELUM UTS")
chk_items = [
    "Minimal 8 screen selesai (Terpenuhi: 10 screen tersedia).",
    "1 persona utama dibuat (Terpenuhi: Budi Pratama - Mahasiswa Rantau).",
    "Minimal 3 user flow berjalan end-to-end (Terpenuhi: 3 Flow Utama).",
    "Minimal 2 modul CRUD selesai (Terpenuhi: Modul Tugas & Keuangan).",
    "Minimal 20 record utama & 5 record referensi (Terpenuhi: 20 Record Utama + 7 Kategori).",
    "Validasi form, Loading state, Empty state, & Error state berfungsi (Terpenuhi).",
    "UI Responsive & Tema Dark/Light berfungsi tanpa glitch (Terpenuhi).",
    "Minimal 20 skenario pengujian selesai dengan hasil Pass (Terpenuhi)."
]
for item in chk_items:
    add_bullet(item, "✔ ")

# --- 14. DAFTAR BERKAS PENGUMPULAN ---
add_h1("14. DAFTAR BERKAS PENGUMPULAN")
add_bullet("Source Code Flutter (ZIP tanpa folder build/ dan .dart_tool/)", "1. ")
add_bullet("Dokumen Dokumentasi Laporan Project Kelompok (Dokumentasi_Project_AturAja.docx)", "2. ")
add_bullet("Video Demonstrasi Aplikasi (Durasi 8-10 menit)", "3. ")

# Save to path
output_path1 = r"C:\Semester 5\Reguler\Pemmob\AturAja\Dokumentasi_Project_AturAja.docx"
output_path2 = r"C:\Users\Zidan\Downloads\Dokumentasi_Project_AturAja.docx"

doc.save(output_path1)
doc.save(output_path2)

print(f"Successfully generated docx files at:\n - {output_path1}\n - {output_path2}")
