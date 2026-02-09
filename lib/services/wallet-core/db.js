import mysql from 'mysql2/promise';

// 数据库名
const DATABASE = 'DATABASE';

export const pool = mysql.createPool({
  host: 'localhost',
  user: 'user',
  password: 'password.',
  database: DATABASE,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,

  // 关键：避免 BIGINT / DECIMAL 被转成 JS Number 导致精度丢失
  supportBigNumbers: true,
  bigNumberStrings: true,

  decimalNumbers: false,

  // 可选：时区/字符集（按需）
  // timezone: 'Z',
  // charset: 'utf8mb4',
});
