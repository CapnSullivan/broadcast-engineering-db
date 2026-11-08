-- Entirely fictional broadcast system. No production wiring or identifiers.
PRAGMA foreign_keys = ON;
BEGIN;

INSERT INTO models (model_id, note) VALUES
 ('DEMO.SOURCE', 'Fictional video source'),
 ('DEMO.DISPLAY', 'Fictional video receiver'),
 ('VJP.model', 'Generic video jackfield used by the schema views');

INSERT INTO model_ports (model_id, name, io, signal, interface, connector, label, port_group, domain, doc_name, port_role) VALUES
 ('DEMO.SOURCE','SDI_OUT','out','VIDEO_SDI','SDI','BNC','SDI output','SDI','VID','SDI_OUT','OUTPUT'),
 ('DEMO.DISPLAY','SDI_IN','in','VIDEO_SDI','SDI','BNC','SDI input','SDI','VID','SDI_IN','INPUT'),
 ('VJP.model','A01','in','VIDEO_SDI','SDI','BNC','Rear A1','A','VID','A01','INPUT'),
 ('VJP.model','B01','out','VIDEO_SDI','SDI','BNC','Rear B1','B','VID','B01','OUTPUT'),
 ('VJP.model','A02','in','VIDEO_SDI','SDI','BNC','Rear A2','A','VID','A02','INPUT'),
 ('VJP.model','B02','out','VIDEO_SDI','SDI','BNC','Rear B2','B','VID','B02','OUTPUT');

INSERT INTO devices (asb, layer, device_id, model_id, model_name, location_zone, note) VALUES
 ('DEMO', 'DESIGN', 'SRC.01', 'DEMO.SOURCE', 'Demo source', 'LAB', 'Fictional'),
 ('DEMO', 'DESIGN', 'SRC.02', 'DEMO.SOURCE', 'Demo backup source', 'LAB', 'Fictional'),
 ('DEMO', 'DESIGN', 'VJP.01', 'VJP.model', 'Demo jackfield', 'LAB', 'Fictional'),
 ('DEMO', 'DESIGN', 'MON.01', 'DEMO.DISPLAY', 'Demo monitor 1', 'LAB', 'Fictional'),
 ('DEMO', 'DESIGN', 'MON.02', 'DEMO.DISPLAY', 'Demo monitor 2', 'LAB', 'Fictional');

INSERT INTO cables (asb, layer, cable_label, a_device, a_port, b_device, b_port, net_name, domain_raw, source) VALUES
 ('DEMO','DESIGN','C-001','SRC.01','SDI_OUT','VJP.01','A01','DEMO_SIGNAL_1','VID','synthetic'),
 ('DEMO','DESIGN','C-002','VJP.01','B01','MON.01','SDI_IN','DEMO_SIGNAL_1','VID','synthetic'),
 ('DEMO','DESIGN','C-003','SRC.02','SDI_OUT','VJP.01','A02','DEMO_SIGNAL_2','VID','synthetic'),
 ('DEMO','DESIGN','C-004','VJP.01','B02','MON.02','SDI_IN','DEMO_SIGNAL_2','VID','synthetic');

INSERT INTO vjp_normals(model_id, a_port, b_port, normal_dir, break_on_a, break_on_b, note) VALUES
 ('VJP.model','A01','B01','A_TO_B',1,1,'Demo normal 1'),
 ('VJP.model','A02','B02','A_TO_B',1,1,'Demo normal 2');

-- Live patch: the first normal connection is interrupted at A01.
INSERT INTO vjp_live_patches(asb,layer,base_layer,device_id,port_name,peer_device,peer_port,patch_role,active,note) VALUES
 ('DEMO','LIVE','DESIGN','VJP.01','A01','SRC.02','SDI_OUT','PATCH',1,'Synthetic live patch');

-- A program overlay on the second normal connection.
INSERT INTO vjp_program_sets(program_id,name,note) VALUES
 ('DEMO_PROGRAM','Synthetic preset','Demonstration only');
INSERT INTO vjp_active_program(slot_id,program_id,activated_at,note) VALUES
 (1,'DEMO_PROGRAM',NULL,'Demonstration only');
INSERT INTO vjp_program_patches(program_id,asb,layer,base_layer,device_id,port_name,peer_device,peer_port,patch_role,active,note) VALUES
 ('DEMO_PROGRAM','DEMO','PROGRAM','DESIGN','VJP.01','B02','MON.01','SDI_IN','PATCH',1,'Synthetic program patch');

COMMIT;
