# RawCam 📸

A powerful, native iOS manual camera application built with SwiftUI and AVFoundation, designed for photographers who want complete control over their shots. Captures professional RAW (DNG) + HEIC formats and renders real-time RGB histograms.

*SwiftUI ve AVFoundation ile geliştirilmiş, fotoğrafçılara çekimlerinde tam kontrol sunan güçlü bir yerel iOS manuel kamera uygulaması. Profesyonel RAW (DNG) + HEIC formatlarında çekim yapabilir ve gerçek zamanlı RGB histogram sunar.*

---

## Language / Dil
- [English (#english)](#english)
- [Türkçe (#türkçe)](#türkçe)

---

<a name="english"></a>
## English

### Key Features
*   **Dual Format Capture (RAW + HEIC)**: Shoots raw sensor data (`.DNG` format via Adobe RAW specification) alongside high-quality processed `HEIC` images for maximum editing latitude.
*   **Full Manual Control Overrides**:
    *   **ISO**: Precise slider adjustment based on your device's hardware limits.
    *   **Shutter Speed (SS)**: Fine-tune exposure duration with interactive speed fractions (e.g., 1/8000s up to 1s).
    *   **Focus**: Manual lens position distance slider (from near macro to infinity).
*   **Real-time RGB Histogram**: Video frames are processed live via the Accelerate Framework to render overlapping red, green, and blue color channels for exposure monitoring.
*   **Multi-Camera Lens Switcher**: Seamlessly switch between Wide-angle (1x) and Ultra-wide (0.5x) camera modules.
*   **Quick Presets**: Single-tap shooting profiles to immediately switch to:
    *   *Auto*: Default continuous focus and exposure.
    *   *Portrait*: Shutter optimized for portraits.
    *   *Night*: High ISO, longer shutter speed.
    *   *Action*: Rapid shutter speed (1/1000s) to freeze motion.
    *   *Landscape*: Locked manual focus at infinity.
*   **Responsive UI**: Native adaptive layouts for both Portrait and Landscape view orientations with iOS 17+ rotation angle support.
*   **Tap to Focus**: Tap anywhere on the live preview to center auto-focus and auto-exposure.

### Future Roadmap
1.  **Manual White Balance**: Kelvins (Temperature) & Tint adjustments.
2.  **Focus Peaking**: Highlight edges in sharp focus using custom Metal shaders.
3.  **Zebra Stripes / Clipping Indicators**: Live visualization of overexposed areas.
4.  **Format Selector**: Toggle between RAW only, HEIC only, or RAW+HEIC to save device storage.
5.  **Rule-of-Thirds & Level Guides**: Interactive grids to help frame the perfect composition.

### Requirements
*   **iOS**: iOS 17.0 or later.
*   **Device**: Compatible iPhone (Pro models recommended for RAW DNG support and multiple physical lenses).

---

<a name="türkçe"></a>
## Türkçe

### Temel Özellikler
*   **Çift Format Kayıt (RAW + HEIC)**: Düzenleme esnekliğini en üst düzeye çıkarmak için Adobe RAW standartlarında ham sensör verisini (`.DNG` formatında) ve işlenmiş `HEIC` görselini aynı anda kaydeder.
*   **Tam Manuel Kontrol Seçenekleri**:
    *   **ISO**: Cihaz donanım limitlerine uygun hassas slider kontrolü.
    *   **Enstantane Hızı (SS)**: Pozlama süresini kesirli hızlarla (örn. 1/8000 sn'den 1 sn'ye kadar) ayarlama imkanı.
    *   **Odaklama (Focus)**: Yakın odaktan sonsuza manuel lens pozisyonu ayarlama sürgüsü.
*   **Gerçek Zamanlı RGB Histogram**: Pozlama takibi için video kareleri Accelerate Framework kullanılarak anlık işlenir ve üst üste binen kırmızı, yeşil, mavi renk kanalları çizilir.
*   **Çoklu Lens Seçici**: Geniş Açı (1x) ve Ultra Geniş Açı (0.5x) arka kamera modülleri arasında hızlı geçiş.
*   **Hızlı Çekim Preset'leri**: Tek dokunuşla hazır profiller arasında geçiş:
    *   *Auto*: Varsayılan sürekli otomatik odak ve pozlama.
    *   *Portrait*: Portre çekimleri için optimize edilmiş perde hızı.
    *   *Night*: Yüksek ISO ve daha uzun perde hızı.
    *   *Action*: Hareketi dondurmak için yüksek perde hızı (1/1000 sn).
    *   *Landscape*: Sonsuza kilitlenmiş manuel odak.
*   **Duyarlı (Responsive) Arayüz**: iOS 17+ ekran döndürme açılarına tam uyumlu dikey ve yatay ekran düzenleri.
*   **Dokunarak Odaklama**: Kamera önizleme ekranında herhangi bir yere dokunarak odak ve pozlama noktasını belirleme.

### Gelecek Planları
1.  **Manuel Beyaz Dengesi**: Kelvin (Sıcaklık) ve Renk Tonu (Tint) ayarlama sürgüleri.
2.  **Focus Peaking (Odak Belirginleştirme)**: Metal gölgelendiricileri (shaders) ile odaktaki keskin kenarları canlı renklendirme.
3.  **Zebra Çizgileri**: Aşırı pozlanmış (patlamış) bölgelerin ekranda görsel uyarısı.
4.  **Format Seçici**: Depolama alanından tasarruf etmek için sadece RAW, sadece HEIC ya da RAW+HEIC modları arasında geçiş yapabilme.
5.  **Izgara ve Ufuk Çizgisi**: Altın oran, 3x3 kılavuz çizgileri ve hizalama seviyesi göstergesi.

### Gereksinimler
*   **iOS**: iOS 17.0 veya daha yeni bir sürüm.
*   **Cihaz**: Uyumlu iPhone (RAW DNG desteği ve çoklu lensler için Pro serisi modeller önerilir).
