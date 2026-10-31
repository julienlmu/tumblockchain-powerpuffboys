# Başka AI’a kopyalanacak uygulama görevi

Bu dosyayı, aynı klasördeki ilgili tasarım dokümanı ve JPEG’lerle birlikte ver. Birleştirilmiş yönü uygulamak istiyorsan aşağıdaki görevi doğrudan kullan. Sadece Ledger veya sadece Control Room seçilirse tasarım dosyası adını değiştir.

---

SupplierPulse+ projemizin UI’ını aşağıdaki tasarıma göre yeniden oluştur:

**Hedef tasarım: `design/ui-concepts/LEDGER_CONTROL_ROOM.md` — Ledger + Control Room.**

Bu hedef bu kopyalanabilir görevin önerilen seçimidir; kullanıcı başka yön seçerse onu esas al.

Önce şunları oku:

1. `design/ui-concepts/README.md`
2. `design/ui-concepts/LEDGER_CONTROL_ROOM.md`
3. `design/ui-concepts/SHARED_REQUIREMENTS.md`
4. `design/ui-concepts/LEDGER.md` ve `CONTROL_ROOM.md`
5. `design/ui-concepts/screenshots/combined-simple.jpg` ve `combined-complex.jpg`
6. Doğrulama ekranına ait aynı klasördeki iki `combined-verification-*.jpg`
7. Güncel `docs/SUPPLIERPULSE_PLUS.md`, `demo/README.md`, `demo/index.html`, `demo/common.js`, `demo/judge.html`, `api3/src/ISupplierPulsePlus.sol` ve ilgili takım TODO’su.

Görsel dil:

- Ledger’ın sol navigasyonu, serif başlığı, sakin lacivert/nötr paleti ve finans hiyerarşisi.
- Control Room’un seçili siparişe bağlı ödeme koşulları, kanıt, ajan politikası ve karar geçmişi.
- Simple ve Complex seçenekleri zorunlu. Simple gerçek karar nedenini saklamaz; Complex teknik ayrıntıları açar.
- İki dashboard’u alt alta koyma. Tek finans özeti, tek navigasyon, tek seçili order bağlamı kullan.
- Arayüz metinleri İngilizce; görev iletişimi Türkçe olabilir.
- Görselleri tasarım referansı olarak uygula. Görseldeki örnek tutarları, Approved/Upcoming/Expired gibi sabit durumları gerçek kodun içine yerleştirme.

Çalışma şekli:

- Çalışmaya başlamadan güncel branch’leri ve yerel değişiklikleri kontrol et. Başkasının çalışmasını koru; ayrı `codex/` branch veya ekip standardına uygun izole çalışma kullan.
- Başlangıç paketinin tabanı `main` 56cbd27. Sonraki commitleri ve özellikle `batu/plus-ui`, `orhun/plus-ui-f10`, `orhun/final-fixes` farklarını yeniden incele; entegrasyon durumunu varsayma.
- Önizleme HTML’lerini görsel kaynak olarak kullan. İçlerindeki yerel senaryo sonuçlarını gerçek doğrulama mantığı yerine koyma.
- Mevcut statik HTML + ethers veri okuma ve işlem akışını koru. Framework/bağımlılık göçü veya kontrat değişikliği bu işin parçası değildir.
- Önce veri, koşul ve event türetme kodunu görünümden ayır; sonra yeni bileşen düzenini aynı veriye bağla.
- Read-only gezinme ücretli API/model çağrısı veya cüzdan işlemi başlatmamalı.
- Gerçek işlem, imza, deployment, signer ayarı veya ücretli çağrı yapmadan örnekler ve mocklar üzerinden doğrula. Canlı doğrulama gerekiyorsa bunu ayrıca belirt.

Ürün doğruluğu:

- Buyer approval, registry evidence, permit ve paid birbirinden farklıdır.
- Supplier recovery geçmiş failure yüzünden yanlış stopped göstermemeli.
- MaxAge, permit lifetime, tarihî kontrol ve güncel izin ayrı kavramlardır.
- No data supplier’ın kötü olduğunu kanıtlamaz; LEI LAPSED iflas değildir.
- Salt/hash varsa belge bütünlüğünü anlatır; teslimat, hukuki imza ve immutable admin iddiasına dönüşmez.
- Para birimi ve veri modu açık; büyük tamsayılar hassasiyetini korur; RPC hatası sıfır bakiye gibi görünmez.
- Kullanıcının kendi imzalı cevabını denediği gerçek judge akışı korunur.

Tamamlanma ölçütleri:

- Desktop ve mobilde Simple/Complex, seçim, filtre, detay, kanıt ve doğrulama alanları çalışıyor.
- `SHARED_REQUIREMENTS.md` kabul listesindeki ilgili maddeler kontrol edildi.
- 320/390/768/1024/1440 px ve açık/koyu tema gözle incelendi; temel klavye ve odak kullanımı çalışıyor.
- Expired permit, onaysız/not due aşama, Held, no-data refund, Closed, supplier recovery, yanlış ağ ve RPC hatası durumları doğrulandı.
- UI’ın güncel ekran görüntüleri ve yapılan kontrollerle kısa sonuç raporu verildi.
- Kontrat, ABI, deployment ve dependency sürümleri bu UI işi sırasında değiştirilmedi.

Önce mevcut kodla uygulanabilirliğini değerlendir; sonra UI’ı gerçekten oluştur. Yalnızca plan veya yeni bir mockup bırakma. Teknik bir sınırlama varsa somut dosya/alanı ve alternatifini belirt.

---

Görseller bulunamıyorsa depo klasörünü veya JPEG’leri de AI’a ver. Markdown metni tek başına görsel referansları taşımaz. GitHub’daki repo erişimi ayrıca gereklidir; bu paket görünürlük/izin ayarlarını değiştirmez.
