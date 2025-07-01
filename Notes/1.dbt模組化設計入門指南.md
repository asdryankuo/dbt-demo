# dbt 模組化設計入門指南

## 📚 什麼是 dbt 模組化？

### 簡單來說
想像你在寫一個超級複雜的 Excel 公式，如果全部寫在一個儲存格裡，會變得很難閱讀和修改。
dbt 模組化就是把這個複雜的公式拆分成多個小的、有意義的部分，讓每個部分都有清楚的職責。

### 為什麼需要模組化？

#### 🚫 傳統 SQL 的問題
```sql
-- 想像這樣的 SQL，有 500 行...
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    -- 100 行的複雜計算...
    (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) as order_count,
    -- 又是 100 行的複雜計算...
    (SELECT SUM(amount) FROM orders o WHERE o.customer_id = c.customer_id) as total_spent,
    -- 更多複雜的子查詢...
FROM customers c
-- 還有更多 JOIN 和 WHERE 條件...
```

**問題：**
- 😵 難以閱讀：一個檔案幾百行，找東西很困難
- 🔄 重複代碼：相同的邏輯在多個地方出現
- 🐛 難以除錯：出錯時不知道問題在哪一段
- 🚧 無法重用：好不容易寫好的邏輯，其他地方用不了

#### ✅ dbt 模組化的解決方案
把大的 SQL 拆分成小的、可管理的模組：

```
大 SQL (500 行) 
    ↓ 拆分成
├── 客戶基本資料處理 (stg_customers.sql)
├── 訂單資料處理 (stg_orders.sql)  
└── 最終分析結果 (customers.sql)
```

## 🏗️ 模組化的架構概念

### 三層架構
```
Raw Data (原始數據)
    ↓
Staging (清理層)
    ↓
Mart (分析層)
```

#### 1. Raw Data (原始數據層)
- **是什麼**：直接從資料庫來的原始資料
- **特色**：通常很髒亂，有重複、缺失、格式不一致的問題
- **例子**：客戶表、訂單表、產品表

#### 2. Staging (清理層)
- **是什麼**：清理和標準化原始資料
- **特色**：一對一的關係，一個原始表對應一個 staging 表
- **命名規則**：`stg_` 開頭，如 `stg_customers`、`stg_orders`
- **工作內容**：
  - 統一欄位名稱
  - 資料型別轉換
  - 基本的資料清理

#### 3. Mart (分析層)
- **是什麼**：組合多個 staging 表，產生可以直接分析的資料
- **特色**：業務邏輯在這裡實現
- **例子**：客戶分析表、銷售報表、庫存分析

## 🛠️ 實際操作步驟

### 步驟 1：了解現有的巨大 SQL

假設我們有一個 `customers.sql`，裡面有 4 個 CTE：
```sql
with 
customers as (
    -- 客戶基本資料處理
    select * from raw_customers
),

orders as (
    -- 訂單資料處理  
    select * from raw_orders
),

customer_orders as (
    -- 客戶訂單統計
    -- 複雜的計算邏輯...
),

final as (
    -- 最終結果
    -- 更複雜的組合邏輯...
)

select * from final
```

### 步驟 2：識別可以拆分的部分

觀察這個 SQL，我們發現：
- `customers` CTE 是在處理客戶資料
- `orders` CTE 是在處理訂單資料
- 這兩個可以獨立成為 staging models

### 步驟 3：建立 Staging Models

#### 3.1 建立檔案結構
```
models/
└── staging/
    ├── sources.yml
    ├── stg_customers.sql
    └── stg_orders.sql
```

#### 3.2 建立 sources.yml
```yaml
version: 2

sources:
  - name: jaffle_shop          # 資料來源名稱
    database: dbt-tutorial     # 資料庫名稱
    schema: jaffle_shop        # Schema 名稱
    tables:
      - name: customers        # 原始客戶表
      - name: orders          # 原始訂單表
```

**為什麼需要 sources.yml？**
- 📋 清楚列出所有用到的原始資料表
- 🔗 統一管理資料來源的連接資訊
- 📊 在 Lineage 圖中顯示資料流向

#### 3.3 建立 stg_customers.sql
```sql
-- 原本在 customers CTE 裡的邏輯移到這裡
select
    customer_id,
    first_name,
    last_name,
    email
from {{ source('jaffle_shop', 'customers') }}
```

#### 3.4 建立 stg_orders.sql
```sql
-- 原本在 orders CTE 裡的邏輯移到這裡
select
    order_id,
    customer_id,
    order_date,
    amount
from {{ source('jaffle_shop', 'orders') }}
```

### 步驟 4：修改原本的 customers.sql

```sql
with 
customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

-- 其他邏輯保持不變...
customer_orders as (
    -- 客戶訂單統計
),

final as (
    -- 最終結果
)

select * from final
```

## 🔍 重要語法解釋

### `{{ source() }}` 函數
```sql
{{ source('jaffle_shop', 'customers') }}
```
- **用途**：引用在 sources.yml 中定義的原始資料表
- **參數**：
  - `'jaffle_shop'`：source 名稱
  - `'customers'`：table 名稱
- **實際效果**：會被轉換成 `dbt-tutorial.jaffle_shop.customers`

### `{{ ref() }}` 函數
```sql
{{ ref('stg_customers') }}
```
- **用途**：引用其他的 dbt model
- **參數**：model 的檔案名稱（不含 .sql）
- **實際效果**：會被轉換成實際的表格名稱
- **好處**：dbt 會自動處理依賴關係

## 📊 查看成果：Lineage 圖

完成模組化後，在 dbt Cloud 點擊 "Lineage" 可以看到：

```
[customers 原始表] ──→ [stg_customers] ──┐
                                         ├──→ [customers 最終表]
[orders 原始表] ────→ [stg_orders] ──────┘
```

這個圖表告訴我們：
- 資料的流向
- 哪些表依賴哪些表
- 如果某個表有問題，會影響哪些下游的表

## 🎯 模組化的好處

### 1. 提高**可讀性**
- 每個檔案都有明確的職責
- 新人可以快速理解每個部分在做什麼

### 2. 方便**除錯**
- 問題定位更精準
- 可以單獨測試每個模組

### 3. **可重用性**
- `stg_customers` 可以被多個 mart 使用
- 不用重複寫相同的邏輯

### 4. **依賴管理**
- dbt 會自動計算執行順序
- 不用擔心表格還沒建立就被引用

### 5. **團隊協作**
- 不同人可以負責不同的模組
- 減少程式碼衝突

## 🏃‍♂️ 下一步學習

1. **學習 dbt run**：了解這些 model 如何在資料庫中建立
2. **Materializations**：了解 model 可以建立成 view 或 table
3. **測試**：為你的 model 加入資料品質檢查
4. **文件**：為你的 model 加入說明文件

## 💡 實用建議

### 給新人的建議
1. **從小開始**：不要一次拆分太多，先試著拆分 1-2 個 staging model
2. **保持簡單**：staging model 只做基本的清理，複雜邏輯放在 mart 層
3. **命名一致**：建立清楚的命名規則並堅持使用
4. **多看 Lineage**：經常查看依賴關係圖，理解資料流向

### 常見錯誤
- ❌ 在 staging 層放太多業務邏輯
- ❌ 忘記更新 sources.yml
- ❌ 循環依賴（A 依賴 B，B 又依賴 A）

## 🌟 總結

dbt 模組化不只是技術手段，更是一種**思維方式**：

> 把複雜的問題拆分成簡單的、可管理的小問題，然後逐一解決。

這種方法不僅適用於 SQL，也適用於任何複雜的系統設計。掌握了這個概念，你就掌握了現代資料工程的核心思想！