const express = require('express');
const router = express.Router();

module.exports = (db) => {
    // 대기 목록 조회
    router.get('/pending-partners', (req, res) => {
        const sql = "SELECT * FROM partners WHERE status = 'pending'";
        db.query(sql, (err, results) => {
            if (err) return res.status(500).json({ success: false, message: "조회 오류" });
            res.json({ success: true, data: results });
        });
    });

    // 승인 처리
    router.post('/approve-partner', (req, res) => {
        const { id } = req.body;
        const sql = "UPDATE partners SET status = 'approved' WHERE id = ?";
        db.query(sql, [id], (err, result) => {
            if (err) return res.status(500).json({ success: false, message: "승인 오류" });
            res.json({ success: true, message: "승인 완료" });
        });
    });

    return router;
};