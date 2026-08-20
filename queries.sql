-- ============================================================
-- City Profitability Model
-- نموذج ربحية المدن -- 26,397 سطر مبيعات على نموذج نجمي
--
-- النموذج: جدول حقائق واحد في المنتصف، وحوله جداول وصف.
--   sales   <- FactSale.csv       (جدول الحقائق: كل صف عملية بيع)
--   cities  <- DimCity.csv        (بُعد: المدينة والولاية والإقليم)
--   items   <- DimStockItem.csv   (بُعد: المنتج)
--   dates   <- DimDate.csv        (بُعد: التاريخ)
--
-- الربط دائمًا من مفتاح في جدول الحقائق إلى نفس المفتاح في جدول البُعد.
-- ============================================================


-- ── 1. الصورة العامة
SELECT
    COUNT(*)                                             AS sales_lines,
    ROUND(SUM(total_inc_tax))                            AS revenue,
    ROUND(SUM(profit))                                   AS profit,
    ROUND(SUM(profit) * 100.0 / SUM(total_inc_tax), 1)   AS margin_pct,
    SUM(quantity)                                        AS units
FROM sales;
-- 26,397 | $22,855,078 | $9,923,892 | 43.4% | 1,028,670


-- ── 2. أعلى خمس مدن ربحًا
-- الربط ضروري: جدول المبيعات فيه City Key فقط، والاسم في جدول المدن.
SELECT
    c.city,
    ROUND(SUM(s.profit))  AS profit,
    SUM(s.quantity)       AS units
FROM sales s
JOIN cities c ON c.city_key = s.city_key
GROUP BY c.city
ORDER BY profit DESC
LIMIT 5;
-- Akhiok $259,554 | San Jacinto $185,159 | Meadowdale $176,754
-- Haycock $167,999 | Fieldbrook $163,721


-- ── 3. السؤال الحقيقي: هل أكبر مدينة هي الأعلى ربحية؟
-- HAVING تفلتر بعد التجميع (بعكس WHERE اللي تفلتر قبله).
-- استخدمتها عشان أستبعد المدن الصغيرة اللي نسبها غير مستقرة.
SELECT
    c.city,
    ROUND(SUM(s.total_inc_tax))                              AS revenue,
    ROUND(SUM(s.profit) * 100.0 / SUM(s.total_inc_tax), 1)   AS margin_pct
FROM sales s
JOIN cities c ON c.city_key = s.city_key
GROUP BY c.city
HAVING SUM(s.total_inc_tax) > 150000
ORDER BY revenue DESC;
-- 73 مدينة. الأولى Akhiok بـ $623,651 وهامش 41.6% -- تحت المتوسط العام.


-- ── 4. نفس القائمة لكن مرتبة بالهامش، لتوضيح المفارقة
SELECT
    c.city,
    ROUND(SUM(s.total_inc_tax))                              AS revenue,
    ROUND(SUM(s.profit) * 100.0 / SUM(s.total_inc_tax), 1)   AS margin_pct
FROM sales s
JOIN cities c ON c.city_key = s.city_key
GROUP BY c.city
HAVING SUM(s.total_inc_tax) > 150000
ORDER BY margin_pct DESC;
-- الأعلى: Meadowdale 47.3% بإيراد $373,914 -- ثلث حجم Akhiok تقريبًا
-- الأدنى: Venersborg 40.8% بإيراد $371,134


-- ── 5. الربحية حسب الإقليم
SELECT
    c.sales_territory,
    ROUND(SUM(s.total_inc_tax))                              AS revenue,
    ROUND(SUM(s.profit))                                     AS profit,
    ROUND(SUM(s.profit) * 100.0 / SUM(s.total_inc_tax), 1)   AS margin_pct
FROM sales s
JOIN cities c ON c.city_key = s.city_key
GROUP BY c.sales_territory
ORDER BY revenue DESC;


-- ── 6. أعلى المنتجات ربحًا -- نفس الفكرة، بُعد مختلف
-- هذي فايدة النموذج النجمي: تبدّل جدول البُعد وتحصل على سؤال جديد
-- بدون ما تغيّر شي في جدول الحقائق.
SELECT
    i.stock_item,
    ROUND(SUM(s.profit))                                     AS profit,
    ROUND(SUM(s.profit) * 100.0 / SUM(s.total_inc_tax), 1)   AS margin_pct
FROM sales s
JOIN items i ON i.stock_item_key = s.stock_item_key
GROUP BY i.stock_item
ORDER BY profit DESC
LIMIT 10;


-- ============================================================
-- الخلاصة
--
-- الإيراد والهامش ما يتحركان مع بعض. الفرق بين أفضل مدينة
-- وأسوأها 6.5 نقطة، وما له علاقة بالحجم. يعني "أكبر مدينة"
-- و"أفضل مدينة" قائمتان مختلفتان -- ولو وُزّع جهد المبيعات
-- على الإيراد وحده، فهو يتبع القائمة الغلط.
-- ============================================================
