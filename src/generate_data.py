"""Генерация базы интернет-магазина (SQLite): клиенты и заказы за 18 месяцев.

Данные синтетические; удержание и чеки зависят от канала привлечения,
есть сезонность (ноябрь-декабрь) и отменённые заказы.
Запуск: python src/generate_data.py -> data/shop.db
"""
import sqlite3
from pathlib import Path

import numpy as np
import pandas as pd

SEED = 7
START, END = pd.Timestamp("2025-01-01"), pd.Timestamp("2026-06-30")

CHANNELS = {            # доля новых, мес. вероятность повторной покупки, средний чек
    "organic":  (0.30, 0.15, 2900),
    "ads":      (0.35, 0.07, 2600),
    "referral": (0.15, 0.19, 3100),
    "email":    (0.10, 0.17, 2800),
    "bloggers": (0.10, 0.05, 2300),
}
CITIES = ["Москва", "Санкт-Петербург", "Казань", "Екатеринбург", "Новосибирск", "Краснодар"]


def main(out=Path(__file__).resolve().parents[1] / "data" / "shop.db"):
    rng = np.random.default_rng(SEED)
    months = pd.period_range(START, END, freq="M")
    customers, orders = [], []
    cid, oid = 1, 1
    ch_names = list(CHANNELS)
    ch_p = [v[0] for v in CHANNELS.values()]
    for i, m in enumerate(months):
        season = 1.35 if m.month in (11, 12) else 1.0
        n_new = int(rng.normal(900 + 25 * i, 60) * season)
        for _ in range(n_new):
            ch = rng.choice(ch_names, p=ch_p)
            _, p_ret, check = CHANNELS[ch]
            signup = m.start_time + pd.Timedelta(days=int(rng.integers(0, m.days_in_month)))
            customers.append((cid, signup.date().isoformat(), ch, rng.choice(CITIES, p=[.34, .18, .12, .12, .12, .12])))
            # первый заказ в день регистрации, дальше — помесячные повторные покупки
            dates = [signup]
            p = p_ret
            for mm in months[i + 1:]:
                s = 1.3 if mm.month in (11, 12) else 1.0
                if rng.random() < min(p * s, 0.9):
                    dates.append(mm.start_time + pd.Timedelta(days=int(rng.integers(0, mm.days_in_month))))
                    p = min(p * 1.25, 0.55)  # лояльные покупают чаще
                else:
                    p *= 0.8               # без покупок интерес угасает
            sigma = 0.5
            for d in dates:
                amount = round(rng.lognormal(np.log(check) - sigma ** 2 / 2, sigma), 0)
                status = "cancelled" if rng.random() < 0.06 else "delivered"
                orders.append((oid, cid, d.date().isoformat(), amount, status))
                oid += 1
            cid += 1

    out.parent.mkdir(parents=True, exist_ok=True)
    out.unlink(missing_ok=True)
    con = sqlite3.connect(out)
    con.executescript("""
        CREATE TABLE customers (
            customer_id  INTEGER PRIMARY KEY,
            signup_date  TEXT NOT NULL,
            channel      TEXT NOT NULL,
            city         TEXT NOT NULL
        );
        CREATE TABLE orders (
            order_id     INTEGER PRIMARY KEY,
            customer_id  INTEGER NOT NULL REFERENCES customers(customer_id),
            order_date   TEXT NOT NULL,
            amount       REAL NOT NULL,
            status       TEXT NOT NULL CHECK (status IN ('delivered', 'cancelled'))
        );
        CREATE INDEX idx_orders_customer ON orders(customer_id);
        CREATE INDEX idx_orders_date ON orders(order_date);
    """)
    con.executemany("INSERT INTO customers VALUES (?,?,?,?)", customers)
    con.executemany("INSERT INTO orders VALUES (?,?,?,?,?)", orders)
    con.commit()
    con.close()
    print(f"customers={len(customers)} orders={len(orders)} -> {out}")


if __name__ == "__main__":
    main()
