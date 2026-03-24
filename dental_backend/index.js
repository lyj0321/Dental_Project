const express = require('express');
const multer = require('multer'); // [추가] 파일 업로드 라이브러리
const path = require('path');
const fs = require('fs');

const app = express();
const port = 3000;

app.use(express.json());
// [추가] 업로드된 파일을 외부에서 접근 가능하게 설정 (나중에 사진 볼 때 필요)
app.use('/uploads', express.static('uploads'));

// [추가] 업로드 폴더가 없으면 생성하는 로직
const uploadDir = 'uploads';
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir);
}

// [추가] multer 설정: 파일 저장 위치와 이름 결정
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/'); // uploads 폴더에 저장
  },
  filename: (req, file, cb) => {
    // 파일명 중복 방지를 위해 [시간-원래이름]으로 저장
    cb(null, Date.now() + '-' + file.originalname);
  }
});

const upload = multer({ storage: storage });

// [임시 데이터베이스] 서버가 꺼지면 초기화됩니다.
// 실제 서비스 시에는 AWS RDS(MySQL)로 대체될 영역입니다.
let partners = [
  {
    hospitalName: "덴탈파인드 치과",
    email: "admin@dentalfind.com",
    password: "1234",
    phone: "01012345678",
    isApproved: true, // 승인 완료된 계정
    docs: { 
      license: "uploads/sample_license.pdf", 
      business: "uploads/sample_reg.png", 
      report: "uploads/sample_hosp.jpg" 
    }  
  }
];

// 1. [회원가입] - 필수 체크 + 중복 체크 통합 버전
app.post('/partner/signup', upload.fields([
  { name: 'license' },
  { name: 'business' },
  { name: 'report' }
]), (req, res) => {
  const { hospitalName, email, password } = req.body;
  const files = req.files;

  // [기존 기능] 1. 필수 정보 및 3대 서류 누락 체크
  if (!hospitalName || !email || !password || !files || !files.license || !files.business || !files.report) {
    console.log(`[가입거절] 정보 누락`);
    return res.status(400).json({ 
      success: false, 
      message: "모든 정보와 3대 서류를 등록해주세요." 
    });
  }

  // [신규 기능] 2. 이메일 중복 가입 체크
  if (partners.find(p => p.email === email)) {
    console.log(`[가입거절] 중복 이메일: ${email}`);
    return res.status(400).json({ 
      success: false, 
      message: "이미 가입 신청된 이메일입니다." 
    });
  }

  // 3.가입 데이터 저장 (실제 저장된 파일 경로를 기록)
  const newPartner = {
    hospitalName,
    email,
    password,
    docs: {
      license: files.license[0].path,
      business: files.business[0].path,
      report: files.report[0].path
    },
    isApproved: false
  };

  partners.push(newPartner);

  console.log(`[가입신청] 병원명: ${hospitalName}, 서류접수 완료`);
  res.json({ 
    success: true, 
    message: "가입 신청이 완료되었습니다. 관리자 승인 후 이용 가능합니다." 
  });
});

// 2. [로그인] - 승인 여부까지 확인하는 로직
app.post('/partner/login', (req, res) => {
  const { email, password } = req.body;
  const user = partners.find(p => p.email === email && p.password === password);

  if (!user) {
    return res.status(401).json({ success: false, message: "이메일 또는 비밀번호가 틀렸습니다." });
  }

  if (!user.isApproved) {
    return res.status(403).json({ success: false, message: "아직 관리자 승인 대기 중인 계정입니다." });
  }

  console.log(`[로그인] ${user.hospitalName} 접속 성공`);
  res.json({
    success: true,
    message: `${user.hospitalName}님 환영합니다!`,
    token: "JWT_DENTAL_TOKEN_SAMPLE" // 실제 개발 시에는 보안 토큰 발급
  });
});

// 3. [아이디 찾기] - 병원명과 연락처로 이메일 조회
app.post('/partner/find-id', (req, res) => {
  const { hospitalName, phone } = req.body;
  const user = partners.find(p => p.hospitalName === hospitalName && p.phone === phone);

  if (!user) {
    return res.status(404).json({ success: false, message: "일치하는 정보가 없습니다." });
  }

  res.json({ success: true, email: user.email });
});

// 4. [비밀번호 재설정] - 이메일 확인 후 임시 비번 발급(로그)
app.post('/partner/reset-pw', (req, res) => {
  const { email } = req.body;
  const user = partners.find(p => p.email === email);

  if (!user) {
    return res.status(404).json({ success: false, message: "등록되지 않은 이메일입니다." });
  }

  // 실제로는 이메일 발송 로직이 들어가지만, 지금은 서버 로그로 대체
  console.log(`[PW초기화] ${email}로 임시비밀번호 발송함`);
  res.json({ success: true, message: "임시 비밀번호가 이메일로 발송되었습니다." });
});

// [4] 로그아웃 - 클라이언트의 인증 상태를 해제하는 신호 처리
app.post('/partner/logout', (req, res) => {
  // 현재는 메모리 기반의 간단한 구조이므로, 
  // 클라이언트에게 로그아웃이 성공했다는 신호만 보냅니다.
  // (나중에 JWT 토큰이나 세션을 쓰게 되면 여기서 해당 토큰을 무효화합니다.)

  const { email } = req.body; // 누구인지 확인하기 위해 이메일을 받음

  console.log(`[로그아웃] 파트너 계정: ${email}`);
  
  res.json({ 
    success: true, 
    message: "성공적으로 로그아웃되었습니다." 
  });
});



// 서버 실행 및 로그 안내
app.listen(port, "0.0.0.0", () => { // "0.0.0.0"은 모든 연결을 다 받겠다는 뜻입니다.
  console.log(`서버 실행 중: http://localhost:${port}`);
});