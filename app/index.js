const express = require('express');
const { Pool } = require('pg');

const app = express();
const port = process.env.PORT || 8080;

// Conexion a Cloud SQL por socket unix (lo monta Cloud Run)
const pool = new Pool({
  host: `/cloudsql/${process.env.INSTANCE_CONNECTION_NAME}`,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  max: 5,
});

// Crea la tabla al arrancar. Evita tener que conectarse manualmente
// a la base, que es donde mas tiempo se pierde en el montaje.
async function initDb() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS visitas (
        id SERIAL PRIMARY KEY,
        ruta TEXT NOT NULL,
        creado TIMESTAMPTZ DEFAULT now()
      )
    `);
    console.log('tabla visitas lista');
  } catch (e) {
    console.error('error inicializando db:', e.message);
  }
}

// Responde rapido: linea base de latencia
app.get('/', (req, res) => {
  res.json({ ok: true, servicio: 'app-demo', ts: new Date().toISOString() });
});

// Golpea la base: genera metricas de CPU y conexiones en Cloud SQL
app.get('/db', async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT now() AS ahora, count(*) AS visitas FROM visitas'
    );
    await pool.query('INSERT INTO visitas (ruta) VALUES ($1)', ['/db']);
    res.json({
      ok: true,
      ahora: r.rows[0].ahora,
      visitas: Number(r.rows[0].visitas),
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ ok: false, error: e.message });
  }
});

// Endpoint lento: mueve la cola de latencia hacia arriba
app.get('/slow', async (req, res) => {
  const ms = Math.floor(Math.random() * 1500) + 500;
  await new Promise((r) => setTimeout(r, ms));
  res.json({ ok: true, esperado_ms: ms });
});

// Endpoint que falla: genera 5xx para ver el error rate
app.get('/error', (req, res) => {
  res.status(500).json({ ok: false, error: 'falla simulada' });
});

initDb();

app.listen(port, () => console.log(`escuchando en ${port}`));
