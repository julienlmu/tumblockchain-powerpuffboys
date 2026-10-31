# Üç tasarım için ortak ürün ve uygulama kuralları

Bu belge tasarım devri içindir; bağımsız güvenlik denetimi veya güncel zincir durumu raporu değildir. Sözleşme davranışı için kod esas alınır. Hedef branch değişmiş olabileceği için uygulama öncesinde kaynaklar yeniden okunmalıdır.

## Başlangıç kaynakları

| Kaynak | Neden okunmalı? |
| --- | --- |
| [Ürün spesifikasyonu](../../docs/SUPPLIERPULSE_PLUS.md) | SupplierPulse+, milestone, izin ve supplier mantığı |
| [Solidity arayüzü](../../api3/src/ISupplierPulsePlus.sol) | Gerçek alanlar, eventler ve fonksiyonlar |
| [Sözleşme](../../api3/src/SupplierPulsePlus.sol) | İşlem koşulları ve gerçek doğrulama sırası |
| [Dashboard](../../demo/index.html) | Mevcut sample/live okuma, durum türetme ve aksiyonlar |
| [Ortak demo kodu](../../demo/common.js) | ABI, registry eşlemesi ve yardımcılar |
| [Judge ekranı](../../demo/judge.html) | Kullanıcının kendi imzalı cevabıyla doğrulama yapması |
| [Sample veri](../../demo/sample/sample.js) | Tekrarlanabilir durumlar; canlı veri değildir |
| [Sample cevaplar](../../demo/sample/responses.js) | İmzalı cevap örnekleri; baytları korunur |
| [Demo README](../../demo/README.md) | Çalıştırma ve yapılandırma |
| [Ajan config](../../api3/agent/config.py) | Çalışma profili, aralıklar ve bütçe mantığı |
| [Takım TODO](../../docs/TODO.md) | Entegrasyon sahipliği ve branch durumu |

Hazırlık tabanı `main` / `56cbd27`. İncelenen UI ref’i `batu/plus-ui` / `3c6b44c`. Ayrıca `orhun/plus-ui-f10` / `a270fec` recovery ayrımı ve `orhun/final-fixes` / `1d5f5be` gibi daha yeni işler vardır. Bunların ana dala birleştiğini varsayma; uygulamadan önce diff ve merge durumlarını kontrol et. Bu doküman paketi onları merge etmez.

## Veri katmanları ayrı tutulmalı

| Kavram | Anlamı | UI’da yanlış yorum |
| --- | --- | --- |
| Buyer approval | Bir milestone alıcı tarafından onaylandı | Şirket sicili onayı değildir |
| Registry evidence | Kaynaktan gelen imzalı sicil cevabı | Teslimat, ürün kalitesi veya cüzdan sahipliği kanıtı değildir |
| Permit | Belirli ödeme için süresi olan yetki | Para ödendi anlamına gelmez |
| Release | Koşullar sağlandığında gerçek ödeme işlemi | Yalnızca yeşil etiketle tamamlandı denmez |
| Supplier stop | İlgili supplier’ın güncel temel durum kısıtı | Her geçmiş başarısızlık şu anda stop demek değildir |
| No data | Kullanılabilir veri/izin yok | Supplier kötü veya iflas etmiş demek değildir |
| History tier | Kontrol sıklığına etki eden geçmiş | Kredi skoru, hukuki güvence veya ödeme garantisi değildir |
| Document commitment | Belirli belge ve salt’ın hash bağlantısı | Yasal imza, teslimat veya fiyatın doğruluğu değildir |

Gerekli akış: doğru order + doğru registry/request + kabul edilen signer ve zaman + geçerli politika → permit/hold kararı. Ödeme için ayrıca milestone onayı, due time, geçerli permit, aktif order ve güncel supplier kısıtları değerlendirilir. Kesin kontrol sırası sözleşmeden okunur.

## Gerçek veri eşlemesi

| UI alanı | Başlangıç veri kaynağı |
| --- | --- |
| Buyer, payout address, source, supplier ID, request hash, orderRef, kurallar, permit TTL | `orderInfo(orderId)` |
| Milestone tutarları, tarihler ve onaylar | `orderMilestones(orderId)` |
| State, paid, remaining, next milestone, permitValidUntil/permitValid, lastCheck | `orderStatus(orderId)` |
| nextDueDate, nextApproved, failure bits, held/refund zamanı ve tier | `orderSchedule(orderId)` |
| Supplier geçmişi ve güncel temel durum | `supplierRecord(supplierKey)` + hedef kodun karşılaştırma mantığı |
| Kabul edilmiş imzalı veri, digest, imzalı zaman | `EvidenceAccepted` ve mevcut veri/fixture katmanı |
| İzin verildi | `PermitIssued` |
| Gerçek ödeme | `MilestonePaid` + başarılı işlem makbuzu |
| Gerçek iade | `OrderRefunded`; yalnızca Closed etiketinden miktar/olay uydurma |
| İmzalı yanıtın tam imzası | Orijinal response/receipt veya mevcut doğrulama kaydı; her eventin imzayı içerdiğini varsayma |
| Config ve ajan faaliyeti | Gerçek config/log/adapter; bağlanmıyorsa Unknown |

Önerilen view model’de `order`, `milestones`, `latestEvidence`, `permit`, `supplierState`, `activity` ve `dataSource` ayrılabilir. Ekran bu modeli okur; CSS veya görünüm seçimi zincir durumunu değiştirmez.

## Para, zaman ve örnek veri

- Tutarları ağın gerçek birimiyle göster; ETH/wei veya demo birimi açık olmalı. USD karşılığı için gerçek kur yoksa dolar sembolü koyma.
- Wei ve diğer büyük tamsayılar `BigInt`/mevcut ethers yardımcılarıyla işlenmeli; hassasiyet kaybettiren `Number` dönüşümü kullanma.
- Özet toplamlarının kapsamını belirt: tüm yüklenmiş order’lar mı, seçili buyer mı, filtre sonucu mu? Üst finans toplamları ile listede görünen satır sayısını karıştırma.
- Loading/error durumunu sıfır tutar gibi gösterme. Veri okunamadıysa Unknown / Unavailable yaz.
- İmzalı timestamp, zincirde kabul zamanı ve API’nin kaynak veriyi güncelleme zamanı aynı değildir. Bilinmeyen kaynağın güncellenme zamanını uydurma.
- Submission maxAge ile permit lifetime ayrı gösterilir. `maxAge`, ödeme anında kaynağın en fazla o yaşta olduğunu otomatik garanti etmez.
- Zaman damgalarında UTC/yerel etiket ve okunur biçim kullan; sıfıra gelen sayaçları güncelle.
- Görsellerdeki toplamlar örnektir: escrow 3.500, paid 1.000, returned 5.000 demo units. Üretim uygulamasına sabitlenmez.

## Registry ve recovery

- Companies House ve GLEIF ayrı source türleridir. LEI kimliği CH şirket numarası gibi işlenmez.
- CH’de Active olmak, alıcının ek filing kurallarının geçtiği anlamına gelmeyebilir.
- GLEIF LAPSED, yenileme/reverification’ın geciktiğini anlatır; iflas olarak çevrilmez.
- Yeni temiz kayıt sonrası historical failure ile current stopped durumunu ayır. Hedef kodun son başarı/başarısızlık zamanlarını doğru karşılaştır.
- Supplier’ın toparlanması; closed/refunded order’ı yeniden açmaz, eski izni kendiliğinden yenilemez ve milestone ödemesi yapmaz.
- Historical “Last check passed” ile şu anda geçerli permit ayrı etiketlenmeli.

## Judge ve gerçek işlemler

- Önizlemenin senaryo düğmeleri yerel beklenen sonuç üretir. Gerçek uygulamanın judge ekranını bu sabit sonuçlarla değiştirme.
- Kendi signed response’unu yapıştırma/yükleme, orijinal requestHash/timestamp/data/signature alanlarını koruma ve gerçek doğrulama yolunu sürdür.
- Değiştirilmiş veri, gerçek eski cevap, gerçek başka supplier/request cevabı, yanlış signer ve replay ayrı vakalardır.
- Senaryo örneği ile gerçek test sonucu ayrı etiketlenir. “Verified” yazmak için çalışan doğrulayıcı sonucu gerekir.
- Salt okunur gezinme ve Simple/Complex değişimi cüzdan bağlamaz, işlem imzalatmaz, ücretli fetch veya model çağrısı başlatmaz.
- State değiştiren aksiyonun ağını, hedefini, tutarını ve sonucunu mevcut akışta görünür tut. Pending / confirmed / reverted / rejected durumlarını ayır.
- Yetkisiz buyer aksiyonlarını açma; disabled nedeni okunabilir olsun. Hata dönüşünü eski başarılı sonucu göstererek maskeleme.
- Belge/diff araçları entegre edilecekse dış model özeti açık kullanıcı tercihiyle çalışmalı; dosya hash hatası sessiz fallback olmamalı.

## Uygulama kapsamı

Bu görev UI tasarımı ve sonradan UI uygulamasıdır. Kontrat, ABI, deployment, signer config veya dependency sürümü değişikliği gerektirmez. Hedef frontend mevcut statik HTML/ethers yapısıdır; başka stack seçilecekse bu ayrı bir karar olarak belirtilir.

Eski koddaki davranışları kaybetmemek için önce veri okuma/doğrulama/aksiyonları görünümden ayır, sonra yeni görünümü bağla. Yeni tasarım kaynak kodunun örnek senaryolarını gerçek iş mantığı olarak kopyalama.

## Kabul kontrolleri

- [ ] Sample etiketi kalıcı; canlı bağlantı başarısızsa sample’a sessiz geçiş yok.
- [ ] Seçili order, registry kanıtı, permit ve aksiyon aynı kaydı gösteriyor.
- [ ] Simple/Complex ve filtre değişimi işlem göndermiyor, seçimi tutarlı koruyor.
- [ ] Fonlanmış fakat onaysız milestone; onaylı fakat due olmayan milestone doğru görünüyor.
- [ ] Permit yok / geçerli / süresi dolmuş durumları farklı; permit issued ≠ paid.
- [ ] Active / Held / Closed ve refund/no-data zamanları hedef kodla uyumlu.
- [ ] Supplier failure ve sonraki recovery kontrol edilmiş; historical failure yanlış current stop üretmiyor.
- [ ] İade edilmiş order’da release aksiyonu yok; iade doğru alıcı ve eventle gösteriliyor.
- [ ] CH kural ihlali ile GLEIF LAPSED doğru açıklanıyor.
- [ ] Ağ yanlış, cüzdan yok, RPC yok, boş liste ve eksik ajan kaydı okunabilir.
- [ ] Gerçek judge doğrulaması, orijinal baytlar ve başarısız testler korunuyor.
- [ ] 320/390/768/1024/1440 px, açık/koyu tema, klavye, odak ve dokunma hedefleri kontrol edildi.
- [ ] Bekleyen/reddedilen/revert eden işlem eski başarılı durum gibi görünmüyor.
- [ ] Büyük tamsayılar hassasiyetini koruyor; tablo taşması sayfayı bozmuyor.
- [ ] UI için gerekli kontroller geçti; kontrat ve dependency diff’i bu kapsamda boş.
