const express = require('express');
const router = express.Router();

// index.js에서 db와 upload를 매개변수로 넘겨받습니다.
module.exports = (db, upload) => {

  // 1. 회원가입
  router.post('/signup', upload.fields([
    { name: 'license' }, { name: 'business' }, { name: 'report' }
  ]), (req, res) => {
    const { hospitalName, email, password, phone, name, license_num } = req.body;
    const files = req.files;

    if (!hospitalName || !email || !password || !files || !files.license || !files.business || !files.report) {
      return res.status(400).json({ success: false, message: "모든 정보와 3대 서류를 등록해주세요." });
    }

    const sql = `
      INSERT INTO partners 
      (email, password, name, phone, hospital_name, license_num, license_img_url, business_img_url, open_img_url, status) 
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
    `;

    const values = [
      email, password, name, phone, hospitalName, license_num,
      files.license[0].path, files.business[0].path, files.report[0].path
    ];

    db.query(sql, values, (err) => {
      if (err) {
        console.error("DB 에러:", err);
        if (err.code === 'ER_DUP_ENTRY') return res.status(400).json({ success: false, message: "이미 가입된 이메일입니다." });
        return res.status(500).json({ success: false, message: "DB 저장 오류" });
      }
      res.json({ success: true, message: "가입 신청 완료!" });
    });
  });

  // 2. 로그인
  router.post('/login', (req, res) => {
    const { email, password } = req.body;
    const sql = "SELECT * FROM partners WHERE email = ? AND password = ?";
    db.query(sql, [email, password], (err, results) => {
      if (err) return res.status(500).json({ success: false, message: "서버 오류" });
      if (results.length === 0) return res.status(401).json({ success: false, message: "이메일 또는 비밀번호가 틀렸습니다." });

      const user = results[0];
      if (user.status !== 'approved') {
        return res.status(403).json({ success: false, message: "아직 관리자 승인 대기 중입니다." });
      }
      res.json({ success: true, message: `${user.hospital_name}님 환영합니다!`, token: "JWT_TOKEN_SAMPLE" });
    });
  });

  // 3. 아이디 찾기
  router.post('/find-id', (req, res) => {
    const { hospitalName, phone } = req.body;
    const sql = "SELECT email FROM partners WHERE hospital_name = ? AND phone = ?";
    db.query(sql, [hospitalName, phone], (err, results) => {
      if (err) return res.status(500).json({ success: false, message: "조회 오류" });
      if (results.length === 0) return res.status(404).json({ success: false, message: "일치하는 정보가 없습니다." });
      res.json({ success: true, email: results[0].email });
    });
  });

  // 4. 비밀번호 재설정
  router.post('/reset-pw', (req, res) => {
    const { email } = req.body;
    const sql = "SELECT id FROM partners WHERE email = ?";
    db.query(sql, [email], (err, results) => {
      if (err) return res.status(500).json({ success: false, message: "조회 오류" });
      if (results.length === 0) return res.status(404).json({ success: false, message: "등록되지 않은 이메일입니다." });
      console.log(`[PW초기화] ${email}로 임시비밀번호 발송함`);
      res.json({ success: true, message: "임시 비밀번호가 이메일로 발송되었습니다." });
    });
  });

  // 5. 로그아웃
  router.post('/logout', (req, res) => {
    const { email } = req.body;
    console.log(`[로그아웃] 파트너 계정: ${email}`);
    res.json({ success: true, message: "성공적으로 로그아웃되었습니다." });
  });

  return router; // 설정된 라우터를 반환합니다.
};