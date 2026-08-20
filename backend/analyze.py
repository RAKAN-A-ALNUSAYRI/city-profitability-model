"""
Wide World Importers — profitability analysis over a star-schema model.
Standard library only, no installs.

    python backend/analyze.py

Model: 1 fact table (FactSale, 26,397 rows) joined to 5 dimensions
(City, Customer, Date, StockItem, Employee).
"""
import csv, io, os, sqlite3
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "..", "data")
DB   = os.path.join(HERE, "wwi.db")


def load(name):
    with io.open(os.path.join(DATA, name), encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def build():
    fact   = load("FactSale.csv")
    cities = load("DimCity.csv")

    con = sqlite3.connect(DB)
    con.executescript("""
        DROP TABLE IF EXISTS sales; DROP TABLE IF EXISTS cities;
        CREATE TABLE sales(city_key TEXT, customer_key TEXT, item_key TEXT,
                           quantity INTEGER, unit_price REAL, total_inc_tax REAL, profit REAL);
        CREATE TABLE cities(city_key TEXT PRIMARY KEY, city TEXT, state TEXT,
                            country TEXT, territory TEXT);""")

    con.executemany("INSERT INTO cities VALUES(?,?,?,?,?)",
        [(c["City Key"], c["City"], c["State Province"], c["Country"], c["Sales Territory"])
         for c in cities])

    con.executemany("INSERT INTO sales VALUES(?,?,?,?,?,?,?)",
        [(r["City Key"], r["Customer Key"], r["Stock Item Key"],
          int(r["Quantity"] or 0), float(r["Unit Price"] or 0),
          float(r["Total Including Tax"] or 0), float(r["Profit"] or 0)) for r in fact])
    con.commit()
    return con


def report(con):
    rev, profit, units, n = con.execute(
        "SELECT SUM(total_inc_tax), SUM(profit), SUM(quantity), COUNT(*) FROM sales").fetchone()

    print(f"Sales lines        : {n:,}")
    print(f"Revenue (inc. tax) : ${rev:,.0f}")
    print(f"Profit             : ${profit:,.0f}")
    print(f"Profit margin      : {profit/rev*100:.1f}%")
    print(f"Units sold         : {units:,}")
    print()
    print("Top 5 cities by profit:")
    for city, p, u in con.execute("""
            SELECT c.city, SUM(s.profit) p, SUM(s.quantity) u
            FROM sales s JOIN cities c ON c.city_key = s.city_key
            GROUP BY c.city ORDER BY p DESC LIMIT 5"""):
        print(f"  {city:<16} ${p:>10,.0f}   {u:>8,} units")

    print()
    print("Margin spread — are high-revenue cities also high-margin?")
    for city, rev_c, p in con.execute("""
            SELECT c.city, SUM(s.total_inc_tax) r, SUM(s.profit) p
            FROM sales s JOIN cities c ON c.city_key = s.city_key
            GROUP BY c.city HAVING r > 200000 ORDER BY (p*1.0/r) DESC LIMIT 3"""):
        print(f"  best margin : {city:<16} {p/rev_c*100:.1f}%  (${rev_c:,.0f} revenue)")
    for city, rev_c, p in con.execute("""
            SELECT c.city, SUM(s.total_inc_tax) r, SUM(s.profit) p
            FROM sales s JOIN cities c ON c.city_key = s.city_key
            GROUP BY c.city HAVING r > 200000 ORDER BY (p*1.0/r) ASC LIMIT 3"""):
        print(f"  worst margin: {city:<16} {p/rev_c*100:.1f}%  (${rev_c:,.0f} revenue)")


if __name__ == "__main__":
    con = build()
    report(con)
    print("\ndb:", DB)
