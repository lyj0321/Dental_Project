const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const mysql = require('mysql2');

const app = express();
const port = 3000;

const cors = require('cors');
app.use(cors()); // 모든 도메인에서의 접속을 허용합니다!

app.use(express.json());
app.use('/uploads', express.static('uploads'));

// [1] DB 설정
const db = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: '9493',
  database: 'dental_db',
  waitForConnections: true,
  connectionLimit: 10
});

// [2] 업로드 설정
const uploadDir = 'uploads';
if (!fs.existsSync(uploadDir)) { fs.mkdirSync(uploadDir); }
const storage = multer.diskStorage({
  destination: (req, file, cb) => { cb(null, 'uploads/'); },
  filename: (req, file, cb) => { cb(null, Date.now() + '-' + file.originalname); }
});
const upload = multer({ storage: storage });

// [3] 라우터 연결 (쪼개놓은 파일들을 불러오기)
const partnerRouter = require('./routes/partner')(db, upload);
const adminRouter = require('./routes/admin')(db); // admin.js도 같은 방식으로 쪼개서 넣으세요!

app.use('/partner', partnerRouter); 
app.use('/admin', adminRouter);

app.listen(port, "0.0.0.0", () => {
  console.log(`서버 실행 중: http://localhost:${port}`);
});