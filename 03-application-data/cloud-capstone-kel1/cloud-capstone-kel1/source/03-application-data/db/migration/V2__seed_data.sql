INSERT INTO tenant VALUES ('tenant-a','Kampus'), ('tenant-b','Lembaga Sertifikasi');

INSERT INTO exam (tenant_id,title,duration_min) VALUES
 ('tenant-a','Ujian Basis Data',60),
 ('tenant-b','Sertifikasi Cloud Dasar',45);

INSERT INTO question (tenant_id,exam_id,body,correct_option) VALUES
 ('tenant-a',1,'Apa kepanjangan SQL?','A'),
 ('tenant-a',1,'Perintah untuk menghapus tabel?','B'),
 ('tenant-b',2,'Apa itu container?','A'),
 ('tenant-b',2,'Orkestrator container populer?','C');
