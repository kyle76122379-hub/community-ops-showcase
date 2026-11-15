extends Node2D
## HA.NA Farm — Kenney Tiny 시리즈 탑다운 마을
## 아트: kenney.nl (CC0)
## 기능: WASD/터치 이동, 낚시 · 상점 · 강화 · 요리 (서버 API 연동), WebSocket 멀티

const TILE := 64
const SRC := 16
const SCALE := 4
const BUILD_TAG := "b24"
const MAP_W := 40
const MAP_H := 40
const SPEED := 210.0

const DIR_OFF := {"down": Vector2i(0, 1), "up": Vector2i(0, -1),
                  "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}

# ── Tiny Town / Farm / Dungeon 타일 ──
const T_GRASS := [0, 1]
const T_GRASS_FLOWER := 2
const T_DIRT := 40
const T_TREE := [5, 16, 17]
const T_ROOF_TOP := [52, 53, 54]
const T_ROOF_MID := [64, 65, 66]
const T_WALL := [72, 73, 74]
const T_ANIMALS := [120, 121, 122]
const T_PLAYER := 109
const T_MERCHANT := 108
const T_COOK := 84            # dungeon: 마법사 → 요리사
const T_SMITH := 87           # dungeon: 바이킹 → 대장장이
const T_FISHER := 88          # dungeon: 노인 → 어부

# ── 현실 시계 ──
# 게임 속 시간은 현실 시간과 같다(1초 = 1초). NPC 는 밤(20시~다음날 12시)에 집에 있고,
# 낮(12시~20시)에는 마을을 돌아다닌다.
const NPC_OUT_HOUR := 12      # 집에서 나오는 시각(정오)
const NPC_HOME_HOUR := 20     # 집으로 돌아가는 시각(저녁 8시)
const NPC_WALK_SPEED := 38.0  # 초당 픽셀

var tex_farm: Texture2D
var tex_town: Texture2D
var tex_dungeon: Texture2D
var tex_ski: Texture2D
var ui_font: Font

var player: CharacterBody2D
var player_sprite: Sprite2D
var cam: Camera2D
var world: Node2D
var _nb: Node2D          # 노드(채집/채광) 오버레이 레이어 - 지형·건물 위에 항상 그린다
var npcs: Array = []     # 마을을 돌아다니는 NPC 목록
var npc_layer: Node2D
var _last_clock := ""

var facing := "down"
# ── 공간(씬) ──
var scene_id := "town"          # town | shop | smith | cook | fish | dungeon
var stations: Array = []        # [{cell: Vector2i, kind: String}]
var doors: Dictionary = {}      # Vector2i -> {to: String, spawn: Vector2i}
var door_lock := 0.0
var return_cell := TOWN_SPAWN
# ── 대화 ──
var dlg_layer: CanvasLayer
var dlg_box: Panel
var dlg_name: Label
var dlg_body: Label
var dlg_face: TextureRect
var dlg_hint: Label
var dlg_lines: Array = []
var dlg_i := 0
var dlg_cb: Callable = Callable()
var dlg_typing := false
var dlg_text_full := ""
var dlg_chars := 0.0

# ── 공간 이동 페이드 ──
var fade_rect: ColorRect
var fade_busy := false

# ── 낚시 미니게임 ──
var fish_hold := false
var fish_touch_hold := false
var fish_py := 0.5
var fish_fy := 0.5
var fish_t := 0.0
var fish_target := 0.5
var fish_next_jump := 0.0
var fish_progress := 0.45
var fish_pattern := "smooth"
var fish_bar_pct := 0.28
var fish_speed_mult := 1.0
var fish_dir := 1.0
var cast_t := 0.0
var bobber: ColorRect
var fish_nodes := {}
var fish_wait := 0.0
var fish_ui: Node2D
var fish_line: Line2D
var fish_ui_nodes := {}
var sea_boat := Rect2i(6, 4, 5, 4)
var sea_wheel := Vector2i(8, 6)

var dun_state: Dictionary = {}
var dun_logs: Array = []
var dun_busy := false
var lava_cells: Array = []
var dun_floor := 1
const DUN_MAX := 10
const DUN_W := 21
const DUN_H := 15
var dun_grid: Array = []
var monsters: Array = []
var dun_stairs_down := Vector2i(0, 0)
var dun_stairs_up := Vector2i(0, 0)
var dun_hit_cool := 0.0
var dun_target := -1
var battle_open := false
var bt_layer: CanvasLayer
var bt_enemy_tex: TextureRect
var bt_player_tex: TextureRect
var bt_e_name: Label
var bt_e_lv: Label
var bt_e_hp_txt: Label
var bt_e_st_txt: Label
var bt_e_hp: ColorRect
var bt_e_st: ColorRect
var bt_p_name: Label
var bt_p_lv: Label
var bt_p_hp_txt: Label
var bt_p_st_txt: Label
var bt_p_hp: ColorRect
var bt_p_st: ColorRect
var bt_banner: Label
var bt_slash: TextureRect
var look_layer: CanvasLayer
var look_code := "farm:109"
const LOOKS := [
	{"tex": "farm", "idx": 109, "tint": Color(1, 1, 1), "name": "농부"},
	{"tex": "farm", "idx": 109, "tint": Color(0.75, 0.85, 1.0), "name": "푸른 농부"},
	{"tex": "farm", "idx": 109, "tint": Color(1.0, 0.82, 0.75), "name": "붉은 농부"},
	{"tex": "dungeon", "idx": 96, "tint": Color(1, 1, 1), "name": "기사"},
	{"tex": "dungeon", "idx": 96, "tint": Color(0.80, 0.88, 1.0), "name": "푸른 기사"},
	{"tex": "dungeon", "idx": 96, "tint": Color(1.0, 0.80, 0.72), "name": "붉은 기사"},
	{"tex": "dungeon", "idx": 97, "tint": Color(1, 1, 1), "name": "엘프"},
	{"tex": "dungeon", "idx": 97, "tint": Color(0.85, 1.0, 0.85), "name": "숲 엘프"},
	{"tex": "dungeon", "idx": 97, "tint": Color(0.95, 0.86, 1.0), "name": "밤 엘프"},
	{"tex": "dungeon", "idx": 98, "tint": Color(1, 1, 1), "name": "소녀"},
	{"tex": "dungeon", "idx": 98, "tint": Color(1.0, 0.90, 0.80), "name": "금발 소녀"},
	{"tex": "dungeon", "idx": 98, "tint": Color(0.85, 0.95, 1.0), "name": "은발 소녀"},
]
var quest_hint := ""
var walk_t := 0.0
var moving := false
var touch_dir := Vector2.ZERO

# ── 스테이션 (NPC) ──
# 마을 배치 — NPC 마다 자기 집(3×3)이 있고, 문 앞(가운데 아래 칸)에 닿으면 실내로 들어간다.
const HOUSE_SHOP := Vector2i(20, 13)
const HOUSE_SMITH := Vector2i(20, 27)
const HOUSE_COOK := Vector2i(14, 16)
const HOUSE_FISH := Vector2i(26, 16)
const HOUSE_CARP := Vector2i(14, 24)
const CAVE_DOOR := Vector2i(1, 16)      # 던전 입구 — 서쪽 외곽
const TOWN_SPAWN := Vector2i(20, 21)
const ROOM_W := 13
const ROOM_H := 9
const CAVE_W := 13
const CAVE_H := 10
const ROOM_SPAWN := Vector2i(6, 5)
const CAVE_SPAWN := Vector2i(6, 6)
# 연못: 왼쪽 아래 모서리를 중심으로 한 1/4원
const POND_CX := 0.0
const POND_CY := 39.0
const POND_R := 15.0
const PIER_W := 2
const PIER_X := 8
const PIER_Y0 := 16
const PIER_Y1 := 32
const BOAT_AT := Vector2i(13, 34)    # 배 정박지(깊은 물)
# 택지 4칸 (2×2 배치, 각 3×3)
const PLOTS := [Vector2i(24, 27), Vector2i(28, 27), Vector2i(24, 31), Vector2i(28, 31)]

# ── 서버/상점/패널 ──
var http_boot: HTTPRequest
var http_act: HTTPRequest
var boot := {}
var panel_layer: CanvasLayer
var panel: Panel
var panel_mode := ""
var farm_x := 5
var farm_y := 5
var panel_open := false
var panel_msg := ""
var shop_cat := "bait"
var shop_tab := "buy"   # buy | sell
var sell_qty := {}
var sell_page := 0
var cook_slots: Array = []
var cook_page := 0
var cook_pick := false
var fish_state := "idle"      # idle | casting | resolving
var fish_zone := 0.5
var fish_marker := 0.0
var fish_token := ""
var fish_fid := ""
var fish_spot := "pond"

# ── HUD ──
var hud_label: Label
var hud_bars: Array = []
var mm_layer: CanvasLayer
var mm_player_dot: ColorRect
var mm_info: Label
var mm_marker_root: Control
var fish_btn: Button
var hint_label: Label
var toast_label: Label
var toast_t := 0.0

# ── 네트워크 ──
var ws: WebSocketPeer
var net_state := 0
var my_id := ""
var net_url := ""
var others := {}
var send_acc := 0.0
var retry_t := 0.0

var rng := RandomNumberGenerator.new()
var pending := []   # 웹 fetch 응답 대기열


func _ready() -> void:
	rng.randomize()
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	tex_farm = load("res://art/kenney/farm.png")
	tex_town = load("res://art/kenney/town.png")
	tex_dungeon = load("res://art/kenney/dungeon.png")
	tex_ski = load("res://art/kenney/ski.png")
	ui_font = load("res://art/fonts/Galmuri11.ttf")
	_build_player()
	_build_hud()
	_build_dialog()
	_build_fade()
	_build_fish_ui()
	_build_minimap()
	call_deferred("_maybe_choose_look")
	# 개발용: 주소에 debugdungeon=1 이면 던전에서 시작
	if OS.has_feature("web"):
		if str(JavaScriptBridge.eval("location.search", true)).contains("debugdungeon"):
			call_deferred("_enter_scene", "dungeon", Vector2i(1, 1))
	_build_touch()
	_build_world()
	_init_http()
	_connect_net()
	_fetch_boot()


# ──────────────────────────────────────────── 헬퍼
func _sprite(tex: Texture2D, idx: int, pos: Vector2, z: int = -10) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.region_enabled = true
	var col: int = idx % 12
	var row: int = idx / 12
	s.region_rect = Rect2(col * SRC, row * SRC, SRC, SRC)
	s.scale = Vector2(SCALE, SCALE)
	s.position = pos
	s.z_index = z
	return s


func _c(x: int, y: int) -> Vector2:
	return Vector2(x * TILE + TILE / 2, y * TILE + TILE / 2)


func _blocker(w: float, h: float, pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w, h)
	cs.shape = r
	body.add_child(cs)
	world.add_child(body)


func _or(v, d):
	# GDScript 의 `x or y` 는 truthy 일 때 bool 을 반환한다 → 값 기본값에는 이 헬퍼를 쓴다.
	return d if v == null else v


func _dict_of(v) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


func _arr_of(v) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


func _near(a: Vector2i, b: Vector2i, r: int = 1) -> bool:
	return absi(a.x - b.x) <= r and absi(a.y - b.y) <= r


# ──────────────────────────────────────────── 월드
func _build_world() -> void:
	_build_scene()


func _build_scene() -> void:
	if world != null:
		world.queue_free()
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	if _nb != null:
		_nb.queue_free()
	_nb = Node2D.new()
	_nb.name = "Nodes"
	_nb.z_index = 50
	add_child(_nb)
	stations.clear()
	doors.clear()
	npcs.clear()
	if npc_layer != null:
		npc_layer.queue_free()
	match scene_id:
		"town":
			_build_town()
			_build_npcs()
		"sea":
			_build_sea()
		"dungeon":
			_build_dungeon()
		_:
			_build_interior(scene_id)
	_apply_cam_limits()
	_refresh_minimap()


func _apply_cam_limits() -> void:
	var w := MAP_W
	var h := MAP_H
	if scene_id == "dungeon":
		w = DUN_W
		h = DUN_H
	elif scene_id == "sea":
		w = 17
		h = 11
	elif scene_id != "town":
		w = ROOM_W
		h = ROOM_H
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = w * TILE
	cam.limit_bottom = h * TILE


var editor_map_used := false


func _load_editor_map() -> bool:
	# 에디터에서 그린 맵(art/hana_town.tscn)이 있으면 그것을 사용한다
	var path := "res://art/hana_town.tscn"
	if not ResourceLoader.exists(path):
		return false
	var ps = load(path)
	if ps == null:
		return false
	var inst = ps.instantiate()
	world.add_child(inst)
	inst.z_index = -20
	# 맵은 -20..20 (41×41)에 그렸고 게임 좌표는 0..39 — 중앙 정렬
	for child in inst.get_children():
		child.position = Vector2(20.0 * TILE, 20.0 * TILE)
	var layer = inst.get_node_or_null("Ground")
	if layer == null:
		return false
	return layer.get_used_cells().size() > 0


func _build_farm_plots() -> void:
	# 농장 밭 — 서남쪽 잔디에 14×10 경작 구역을 그린다.
	# 상태별 색: 빈 흙(미경작 잔디) / 갈은 흙 / 물 준 흙 / 작물
	var farm: Dictionary = _dict_of(boot.get("farm"))
	var tiles: Dictionary = _dict_of(farm.get("tiles"))
	for gy in FARM_H:
		for gx in FARM_W:
			var cx := FARM_X0 + gx
			var cy := FARM_Y0 + gy
			var base := ColorRect.new()
			base.size = Vector2(TILE, TILE)
			base.position = Vector2(cx * TILE, cy * TILE)
			base.z_index = -5
			var t: Dictionary = _dict_of(tiles.get("%d,%d" % [cx, cy]))
			var col := Color(0.29, 0.45, 0.24)          # 미경작 잔디
			if bool(t.get("tilled", false)):
				col = Color(0.42, 0.30, 0.20)            # 갈은 흙
			if bool(t.get("watered", false)):
				col = Color(0.28, 0.22, 0.15)            # 물 준 흙
			var crop: Dictionary = _dict_of(t.get("crop"))
			if not crop.is_empty():
				var age := int(crop.get("age", 0))
				var need := maxi(1, int(crop.get("days", 1)))
				var ratio := clampf(float(age) / float(need), 0.0, 1.0)
				col = Color(0.30, 0.45 + 0.35 * ratio, 0.20)  # 자랄수록 초록
				if age >= need:
					col = Color(0.95, 0.85, 0.30)        # 수확 가능
			base.color = col
			base.mouse_filter = Control.MOUSE_FILTER_IGNORE
			world.add_child(base)
	# 밭 테두리 표시
	for gx in FARM_W + 1:
		var cx2 := FARM_X0 + gx
		for yy in [FARM_Y0, FARM_Y0 + FARM_H]:
			var b2 := ColorRect.new()
			b2.size = Vector2(3, TILE)
			b2.position = Vector2(cx2 * TILE, yy * TILE)
			b2.color = Color(0.75, 0.62, 0.36, 0.9)
			b2.z_index = -4
			b2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			world.add_child(b2)


func _build_town_forage() -> void:
	# 마을 채집 노드 — 약초/버섯/열매. 하루마다 리스폰된다.
	var payload: Dictionary = _dict_of(boot.get("gather"))
	var nodes: Array = payload.get("nodes", [])
	if OS.has_feature("web"):
		JavaScriptBridge.eval("console.log('[gather] nodes=%d boot_keys=%s')" % [
			nodes.size(), str(boot.keys().slice(0, 8))])
	for n in nodes:
		var nd: Dictionary = _dict_of(n)
		if str(nd.get("kind", "")) != "forage":
			continue
		var px := int(nd.get("x", 0)) * TILE
		var py := int(nd.get("y", 0)) * TILE
		var box := ColorRect.new()
		box.size = Vector2(TILE - 16, TILE - 16)
		box.position = Vector2(px + 8, py + 8)
		box.z_index = 1
		box.color = Color(0.34, 0.66, 0.34)
		if not bool(nd.get("can", true)):
			box.color = Color(0.45, 0.35, 0.30)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_nb.add_child(box)
		var lbl := Label.new()
		lbl.text = str(nd.get("name", ""))
		lbl.position = Vector2(px - 12, py - 12)
		lbl.size = Vector2(TILE + 24, 14)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", ui_font)
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.add_theme_color_override("font_color", Color(1, 0.98, 0.88))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.z_index = 2
		_nb.add_child(lbl)


func _build_town() -> void:
	editor_map_used = _load_editor_map()
	for y in MAP_H:
		for x in MAP_W:
			var idx: int = 0
			var hsh := (x * 13 + y * 5) % 29
			if hsh == 0:
				idx = T_GRASS_FLOWER      # 꽃 한 송이
			elif hsh == 7:
				idx = 1                   # 잔디 점무늬
			world.add_child(_sprite(tex_town, idx, _c(x, y), -10))

	_build_pond()
	_build_farm_plots()
	_build_town_forage()

	# ── 길: 십자 대로 + 중앙 광장 ──
	for x in MAP_W:
		for yy in [20]:
			world.add_child(_sprite(tex_town, int(T_DIRT), _c(x, yy), 0))
	for y in MAP_H:
		for xx in [20]:
			world.add_child(_sprite(tex_town, int(T_DIRT), _c(xx, y), 0))
	# 광장 (16..23 x 17..24)
	for y in range(19, 23):
		for x in range(18, 22):
			world.add_child(_sprite(tex_town, int(T_DIRT), _c(x, y), 0))
	# 광장 테두리 꽃
	for i in 24:
		var a := float(i) / 24.0 * TAU
		var fx := 19 + int(cos(a) * 5.0)
		var fy := 20 + int(sin(a) * 5.0)
		if fx >= 0 and fy >= 0 and fx < MAP_W and fy < MAP_H:
			world.add_child(_sprite(tex_town, T_GRASS_FLOWER, _c(fx, fy), -9))

	# ── 울타리: 목장(오른쪽 위) + 택지 둘레 ──
	for x in range(27, 36):
		world.add_child(_sprite(tex_town, 45, _c(x, 9), 1))
		world.add_child(_sprite(tex_town, 45, _c(x, 15), 1))
	for y in range(9, 16):
		world.add_child(_sprite(tex_town, 69, _c(27, y), 1))
		world.add_child(_sprite(tex_town, 69, _c(35, y), 1))
	# 목장 안 동물
	for i in 3:
		world.add_child(_sprite(tex_town, int(T_ANIMALS[i % T_ANIMALS.size()]),
			_c(29 + i * 2, 11 + (i % 2)), -1))

	# ── 광장 우물 ──
	for wy in [20, 21]:
		for wx in [19, 20]:
			world.add_child(_sprite(tex_town, int(T_DIRT), _c(wx, wy), 0))
	world.add_child(_sprite(tex_town, 43, _c(19, 20), 1))
	world.add_child(_sprite(tex_town, 43, _c(20, 20), 1))
	world.add_child(_sprite(tex_town, 92, _c(19, 20), 3))
	_blocker(TILE, TILE, _c(19, 20))

	# ── 집마다 진입로 ──
	for h in [HOUSE_SHOP, HOUSE_SMITH, HOUSE_COOK]:
		var hx: int = h.x + 1
		for y in range(h.y + 3, 20):
			world.add_child(_sprite(tex_town, int(T_DIRT), _c(hx, y), 0))
	for h2 in [HOUSE_FISH, HOUSE_CARP]:
		var hx2: int = h2.x + 1
		for y in range(21, h2.y):
			world.add_child(_sprite(tex_town, int(T_DIRT), _c(hx2, y), 0))
	# 광장에서 밭으로 가는 샛길
	for x in range(24, 36):
		world.add_child(_sprite(tex_town, int(T_DIRT), _c(x, 24), 0))

	# ── 밭: 작물 블록 3개 ──
	for f in [Vector2i(25, 26), Vector2i(30, 26), Vector2i(25, 30)]:
		var o: Vector2i = f
		for dy in 3:
			for dx in 4:
				world.add_child(_sprite(tex_town, int(T_DIRT), _c(o.x + dx, o.y + dy), 0))
				world.add_child(_sprite(tex_town, 5, _c(o.x + dx, o.y + dy), 1))
		for dx in range(-1, 5):
			world.add_child(_sprite(tex_town, 45, _c(o.x + dx, o.y - 1), 1))
			_blocker(TILE, TILE, _c(o.x + dx, o.y - 1))
		for dy in range(3):
			world.add_child(_sprite(tex_town, 69, _c(o.x - 1, o.y + dy), 1))
			world.add_child(_sprite(tex_town, 69, _c(o.x + 4, o.y + dy), 1))
		for dx2 in range(-1, 5):
			world.add_child(_sprite(tex_town, 45, _c(o.x + dx2, o.y + 3), 1))

	# ── 소품: 통/화분/표지판 ──
	var props := [
		[Vector2i(14, 6), 92], [Vector2i(22, 6), 94], [Vector2i(28, 6), 92],
		[Vector2i(16, 18), 94], [Vector2i(23, 18), 92], [Vector2i(16, 23), 92],
		[Vector2i(23, 23), 94], [Vector2i(11, 20), 92], [Vector2i(29, 20), 92],
		[Vector2i(18, 16), 92], [Vector2i(21, 16), 94], [Vector2i(18, 25), 92],
		[Vector2i(21, 25), 94], [Vector2i(24, 25), 92], [Vector2i(35, 25), 92],
		[Vector2i(12, 8), 92], [Vector2i(26, 8), 94],
	]
	for pr in props:
		world.add_child(_sprite(tex_town, int(pr[1]), _c((pr[0] as Vector2i).x, (pr[0] as Vector2i).y), 2))

	# NPC 집 — 집마다 지붕 색/벽을 다르게
	_house(HOUSE_SHOP, "shop", "상점", Color(0.95, 0.30, 0.16), 0)
	_house(HOUSE_SMITH, "smith", "대장간", Color(0.28, 0.34, 0.78), 1)
	_house(HOUSE_COOK, "cook", "요리", Color(0.96, 0.74, 0.12), 2)
	_house(HOUSE_FISH, "fish", "낚시", Color(0.10, 0.58, 0.90), 0)
	_house(HOUSE_CARP, "carpenter", "목수", Color(0.58, 0.36, 0.12), 1)
	# ── 집마다 울타리 마당 + 꽃밭 ──
	for hz in [HOUSE_SHOP, HOUSE_SMITH, HOUSE_COOK, HOUSE_FISH, HOUSE_CARP]:
		var y0: int = hz.y - 1
		var y1: int = hz.y + 4
		var x0: int = hz.x - 1
		var x1: int = hz.x + 3
		for xx in range(x0, x1 + 1):
			for yy in [y0, y1]:
				if yy >= 0 and yy < MAP_H and xx >= 0 and xx < MAP_W:
					world.add_child(_sprite(tex_town, 45, _c(xx, yy), 1))
					_blocker(TILE, TILE, _c(xx, yy))
		for yy in range(y0, y1 + 1):
			for xx in [x0, x1]:
				if yy >= 0 and yy < MAP_H and xx >= 0 and xx < MAP_W:
					world.add_child(_sprite(tex_town, 69, _c(xx, yy), 1))
					_blocker(TILE, TILE, _c(xx, yy))
		# 마당 꽃밭
		for gx in range(x0 + 1, x1):
			if (gx + y1) % 2 == 0:
				world.add_child(_sprite(tex_town, T_GRASS_FLOWER, _c(gx, y1 - 1), -9))

	_cave_entrance(CAVE_DOOR)

	# 택지 표시
	for i in PLOTS.size():
		_plot_marker(PLOTS[i], i + 1)

	# 나무
	# ── 꽃 군락 / 덤불 ──
	var clusters := [Vector2i(14, 16), Vector2i(26, 16), Vector2i(15, 26), Vector2i(30, 32)]
	for cl in clusters:
		for i in 7:
			var fx: int = cl.x + (i * 3) % 4
			var fy: int = cl.y + (i * 5) % 3
			if fx >= 0 and fy >= 0 and fx < MAP_W and fy < MAP_H:
				world.add_child(_sprite(tex_town, T_GRASS_FLOWER, _c(fx, fy), -9))
	# 집 앞 정원 덤불
	for g in [Vector2i(12, 8), Vector2i(19, 8), Vector2i(25, 8), Vector2i(24, 23), Vector2i(29, 23)]:
		world.add_child(_sprite(tex_town, 5, _c(g.x, g.y), -9))

	# ── 숲: 가장자리 밀집 (길/집 회피) ──
	var ti := 0
	for y in MAP_H:
		for x in MAP_W:
			var edge := x < 5 or x > 34 or y < 4 or (y > 35 and x > 16)
			if not edge:
				continue
			if _in_pond(Vector2i(x, y)):
				continue
			if ((x * 11 + y * 7) % 2) != 0:
				continue
			_tree(Vector2i(x, y), ti)
			ti += 1
	# 마을 안쪽 산개 나무
	var trees := [Vector2i(10, 10), Vector2i(29, 27), Vector2i(33, 31), Vector2i(12, 30),
		Vector2i(6, 12), Vector2i(31, 12), Vector2i(25, 34), Vector2i(17, 33)]
	for i in trees.size():
		_tree(trees[i], ti + i)


func _in_pond(cell: Vector2i) -> bool:
	var dx := float(cell.x) + 0.5 - POND_CX
	var dy := float(cell.y) + 0.5 - POND_CY
	return sqrt(dx * dx + dy * dy) <= POND_R


func _on_pier(cell: Vector2i) -> bool:
	# 선착장은 2칸 폭 — 폭 전체를 통행 가능하게 둔다
	return cell.x >= PIER_X and cell.x < PIER_X + PIER_W \
		and cell.y >= PIER_Y0 and cell.y <= PIER_Y1


func _build_pond() -> void:
	# 1/4원 물 + 모래 둑 + 나무 선착장
	for y in MAP_H:
		for x in MAP_W:
			var cell := Vector2i(x, y)
			if not _in_pond(cell):
				continue
			# 물
			var w := ColorRect.new()
			w.color = Color(0.19, 0.44, 0.70) if (x + y) % 2 == 0 else Color(0.23, 0.50, 0.78)
			w.size = Vector2(TILE, TILE)
			w.position = Vector2(x * TILE, y * TILE)
			w.z_index = -9
			world.add_child(w)
			if not _on_pier(cell):
				_blocker(TILE, TILE, _c(x, y))

	# 물가 모래
	for y in MAP_H:
		for x in MAP_W:
			var cell := Vector2i(x, y)
			if _in_pond(cell):
				continue
			var near := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _in_pond(cell + d):
					near = true
					break
			if near:
				var sand := ColorRect.new()
				sand.color = Color(0.85, 0.78, 0.58)
				sand.size = Vector2(TILE, TILE)
				sand.position = Vector2(x * TILE, y * TILE)
				sand.z_index = -8
				world.add_child(sand)

	# 선착장 — 길게 뻗은 나무 판자 + 양쪽 난간 말뚝
	for y in range(PIER_Y0, PIER_Y1 + 1):
		var deck := ColorRect.new()
		deck.color = Color(0.56, 0.39, 0.23) if y % 2 == 0 else Color(0.50, 0.34, 0.19)
		deck.size = Vector2(TILE * PIER_W + 10, TILE)
		deck.position = Vector2(PIER_X * TILE - 5, y * TILE)
		deck.z_index = -2
		world.add_child(deck)
		for k in 4:
			var line := ColorRect.new()
			line.color = Color(0.33, 0.21, 0.11, 0.5)
			line.size = Vector2(TILE * PIER_W, 2)
			line.position = Vector2(PIER_X * TILE, y * TILE + 6 + k * 15)
			line.z_index = -1
			world.add_child(line)
		# 난간 말뚝 (양옆)
		for side in [0, 1]:
			var post := ColorRect.new()
			post.color = Color(0.30, 0.19, 0.10)
			post.size = Vector2(9, 20)
			post.position = Vector2(PIER_X * TILE - 9 + side * (TILE * PIER_W + 8), y * TILE + TILE - 22)
			post.z_index = 1
			world.add_child(post)
	# 난간 가로대
	for side in [0, 1]:
		var rail := ColorRect.new()
		rail.color = Color(0.38, 0.25, 0.13)
		rail.size = Vector2(5, (PIER_Y1 - PIER_Y0 + 1) * TILE - 16)
		rail.position = Vector2(PIER_X * TILE - 7 + side * (TILE * PIER_W + 7), PIER_Y0 * TILE + 10)
		rail.z_index = 1
		world.add_child(rail)

	# 배 정박지 — 깊은 물 위 작은 나무 플랫폼
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := Vector2i(BOAT_AT.x + dx, BOAT_AT.y + dy)
			if not _in_pond(c):
				continue
			var deck := ColorRect.new()
			deck.color = Color(0.46, 0.31, 0.17) if (dx + dy) % 2 == 0 else Color(0.41, 0.27, 0.14)
			deck.size = Vector2(TILE, TILE)
			deck.position = Vector2(c.x * TILE, c.y * TILE)
			deck.z_index = -2
			world.add_child(deck)
	stations.append({"cell": Vector2i(PIER_X, PIER_Y1), "kind": "boat"})

	# 낚시 포인트 (선착장 끝)
	var fp := Vector2i(PIER_X, PIER_Y1)
	stations.append({"cell": fp, "kind": "fish_sp"})
	var sign_l := Label.new()
	sign_l.text = "낚시 포인트"
	sign_l.position = _c(fp.x, fp.y) + Vector2(-40, -30)
	sign_l.add_theme_font_override("font", ui_font)
	sign_l.add_theme_font_size_override("font_size", 10)
	sign_l.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	sign_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	sign_l.add_theme_constant_override("outline_size", 4)
	sign_l.z_index = 6
	world.add_child(sign_l)


func _house(origin: Vector2i, kind: String, label: String, roof_tint: Color, wall_variant: int) -> void:
	for i in 3:
		world.add_child(_sprite(tex_town, int(T_ROOF_TOP[i]), _c(origin.x + i, origin.y), 1))
		world.add_child(_sprite(tex_town, int(T_ROOF_MID[i]), _c(origin.x + i, origin.y + 1), 1))
		world.add_child(_sprite(tex_town, int(T_WALL[(i + wall_variant) % 3]), _c(origin.x + i, origin.y + 2), 1))
	# 지붕 색 — 스프라이트 위에 반투명 색판을 덮어 집마다 확실히 구분한다
	for i in 3:
		for row in 2:
			var tint := ColorRect.new()
			tint.color = Color(roof_tint.r, roof_tint.g, roof_tint.b, 0.62)
			tint.size = Vector2(TILE, TILE)
			tint.position = Vector2((origin.x + i) * TILE, (origin.y + row) * TILE)
			tint.z_index = 2
			world.add_child(tint)
	# 벽 충돌 — 가운데(문) 칸은 비워 통행 가능하게
	for i in 3:
		if i != 1:
			_blocker(TILE - 4, TILE - 10, _c(origin.x + i, origin.y + 2))
	# 지붕 두 줄은 통째로 막는다 — 문은 벽 줄 가운데로만 들어가게
	for row in [0, 1]:
		_blocker(TILE * 3 - 6, TILE - 4, _c(origin.x + 1, origin.y + row))

	var door_cell := Vector2i(origin.x + 1, origin.y + 2)
	var door := ColorRect.new()
	door.color = Color(0.26, 0.15, 0.08)
	door.size = Vector2(26, 32)
	door.position = Vector2(door_cell.x * TILE + TILE / 2 - 13, door_cell.y * TILE + TILE - 32)
	door.z_index = 2
	world.add_child(door)
	var knob := ColorRect.new()
	knob.color = Color(0.85, 0.72, 0.35)
	knob.size = Vector2(4, 4)
	knob.position = door.position + Vector2(18, 16)
	knob.z_index = 3
	world.add_child(knob)

	var l := Label.new()
	l.text = label
	l.position = _c(origin.x + 1, origin.y) + Vector2(-20, -46)
	l.add_theme_font_override("font", ui_font)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(1, 0.96, 0.82))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.z_index = 6
	world.add_child(l)

	doors[door_cell] = {"to": kind, "spawn": ROOM_SPAWN}


# ── 현실 시계 ──
# 게임 속 시간을 현실 시각과 동일하게 돌려준다. OS 시계를 그대로 읽으므로
# 브라우저(웹)든 데스크톱이든 1초 = 1초로 흐르고, 자정·정오도 현실과 맞는다.
func _now_sec() -> float:
	var t := Time.get_time_dict_from_system()
	return float(int(t.get("hour", 0)) * 3600 + int(t.get("minute", 0)) * 60 + int(t.get("second", 0)))


func _now_hour_float() -> float:
	var t := Time.get_time_dict_from_system()
	return float(t.get("hour", 0)) + float(t.get("minute", 0)) / 60.0


func _is_npc_outside() -> bool:
	# 12:00 이상 20:00 미만 = 마을 활동 시간
	var h := _now_hour_float()
	return h >= float(NPC_OUT_HOUR) and h < float(NPC_HOME_HOUR)


func _clock_text() -> String:
	var t := Time.get_time_dict_from_system()
	return "%02d:%02d" % [int(t.get("hour", 0)), int(t.get("minute", 0))]


# NPC 정의 — kind, 집 좌표, 집 앞(대기) 칸, 배회 반경
func _npc_defs() -> Array:
	return [
		{"kind": "shop", "house": HOUSE_SHOP, "door": Vector2i(HOUSE_SHOP.x + 1, HOUSE_SHOP.y + 3), "idx": T_MERCHANT, "tex": tex_farm, "name": "상인"},
		{"kind": "smith", "house": HOUSE_SMITH, "door": Vector2i(HOUSE_SMITH.x + 1, HOUSE_SMITH.y + 3), "idx": T_SMITH, "tex": tex_dungeon, "name": "대장장이"},
		{"kind": "cook", "house": HOUSE_COOK, "door": Vector2i(HOUSE_COOK.x + 1, HOUSE_COOK.y + 3), "idx": T_COOK, "tex": tex_dungeon, "name": "요리사"},
		{"kind": "fish", "house": HOUSE_FISH, "door": Vector2i(HOUSE_FISH.x + 1, HOUSE_FISH.y + 3), "idx": T_FISHER, "tex": tex_dungeon, "name": "어부"},
		{"kind": "carpenter", "house": HOUSE_CARP, "door": Vector2i(HOUSE_CARP.x + 1, HOUSE_CARP.y + 3), "idx": T_SMITH, "tex": tex_farm, "name": "목수"},
	]


func _build_npcs() -> void:
	if npc_layer != null:
		npc_layer.queue_free()
	npcs.clear()
	npc_layer = Node2D.new()
	npc_layer.name = "NPCs"
	npc_layer.z_index = 40
	add_child(npc_layer)
	for d in _npc_defs():
		var nd: Dictionary = d
		var home: Vector2i = nd["house"]
		var door: Vector2i = nd["door"]
		var spr := Sprite2D.new()
		spr.texture = nd["tex"]
		spr.hframes = 12
		spr.vframes = 11
		spr.frame = int(nd["idx"])
		spr.scale = Vector2(4, 4)
		var home_px := Vector2(float(door.x + 0.5) * TILE, float(door.y + 0.5) * TILE)
		spr.position = home_px
		spr.z_index = 40
		npc_layer.add_child(spr)
		var lbl := Label.new()
		lbl.text = str(nd["name"])
		lbl.position = Vector2(-26, -46)
		lbl.size = Vector2(52, 16)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", ui_font)
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", Color(1, 0.98, 0.86))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.z_index = 41
		spr.add_child(lbl)
		npcs.append({
			"kind": nd["kind"],
			"name": nd["name"],
			"home": home_px,
			"sprite": spr,
			"target": home_px,
			"wait_t": 0.0,
			"inside": true,
			"door": door,
		})
	_update_npcs(0.0, true)


# 매 프레임: 현실 시각에 따라 NPC 를 집에 넣거나 마을로 내보낸다.
func _npc_tick(delta: float) -> void:
	_update_npcs(delta, false)


func _update_npcs(delta: float, initial: bool) -> void:
	if npcs.is_empty():
		return
	var outside := _is_npc_outside()
	for e in npcs:
		var n: Dictionary = e
		var spr: Sprite2D = n["sprite"]
		if spr == null or not is_instance_valid(spr):
			continue
		# 상태 전환 — 시간대가 바뀌면 목표를 다시 잡는다
		if bool(n["inside"]) == outside:
			if outside:
				n["inside"] = false
				n["target"] = _npc_pick_target(n)
				n["wait_t"] = 0.0
			else:
				n["inside"] = true
				n["target"] = n["home"]
				n["wait_t"] = 0.0
		if bool(n["inside"]) and not outside:
			# 집에 있는 동안은 문 앞에 서 있고, 집이 반투명해진다
			spr.modulate = Color(1, 1, 1, 0.0)
			spr.position = n["home"]
			continue
		spr.modulate = Color(1, 1, 1, 1)
		if initial:
			spr.position = n["target"]
			continue
		# 마을 배회 — 목표 지점까지 걸어가고, 도착하면 잠시 쉰다
		var cur: Vector2 = spr.position
		var tgt: Vector2 = n["target"]
		var gap := tgt - cur
		if gap.length() < 6.0:
			n["wait_t"] = float(n["wait_t"]) + delta
			if float(n["wait_t"]) >= 2.4:
				n["target"] = _npc_pick_target(n)
				n["wait_t"] = 0.0
		else:
			var step := NPC_WALK_SPEED * delta
			spr.position = cur + gap.normalized() * step
			# 걸을 때 위아래로 살짝 흔든다
			var bob := sin(Time.get_ticks_msec() / 140.0) * 2.0
			spr.position.y += bob


# 배회 목표 — 집 근처 광장 쪽으로 반경 6칸 안의 점
func _npc_pick_target(n: Dictionary) -> Vector2:
	var home: Vector2 = n["home"]
	var door: Vector2i = n["door"]
	var base := Vector2(float(door.x), float(door.y))
	for attempt in 24:
		var ang := randf() * TAU
		var rad := 1.4 + randf() * 5.0
		var c := base + Vector2(cos(ang), sin(ang)) * rad
		var cx := int(round(c.x))
		var cy := int(round(c.y))
		if cx < 2 or cy < 2 or cx > 37 or cy > 37:
			continue
		if _cell_blocked(Vector2i(cx, cy)):
			continue
		return Vector2((float(cx) + 0.5) * TILE, (float(cy) + 0.5) * TILE)
	return home


func _cell_blocked(cell: Vector2i) -> bool:
	# 집 footprint(3x3) 안이면 막힌 것으로 본다
	for d in _npc_defs():
		var h: Vector2i = (d as Dictionary)["house"]
		if cell.x >= h.x and cell.x < h.x + 3 and cell.y >= h.y and cell.y < h.y + 3:
			return true
	return false


func _nearest_npc() -> Dictionary:
	# 플레이어와 1.6칸 이내에서 가장 가까운 NPC
	var p := _player_cell()
	var best: Dictionary = {}
	var best_d := 999.0
	for e in npcs:
		var n: Dictionary = e
		var spr: Sprite2D = n["sprite"]
		if spr == null or not is_instance_valid(spr):
			continue
		if spr.modulate.a < 0.2:
			continue
		var cell := Vector2i(int(spr.position.x / TILE), int(spr.position.y / TILE))
		var d := Vector2(float(cell.x - p.x), float(cell.y - p.y)).length()
		if d < 1.7 and d < best_d:
			best_d = d
			best = n
	return best


func _plot_marker(origin: Vector2i, num: int) -> void:
	var mine := _my_plot_slot()
	for y in 3:
		for x in 3:
			var cell := Vector2i(origin.x + x, origin.y + y)
			var pad := ColorRect.new()
			pad.color = Color(0.62, 0.55, 0.40) if mine == num - 1 else Color(0.58, 0.52, 0.38)
			pad.size = Vector2(TILE - 6, TILE - 6)
			pad.position = Vector2(cell.x * TILE + 3, cell.y * TILE + 3)
			pad.z_index = -7
			world.add_child(pad)
	if mine == num - 1 and bool(_my_plot_built()):
		# 내 집 — 목수가 지어준 집
		for i in 3:
			var r := _sprite(tex_town, int(T_ROOF_TOP[i]), _c(origin.x + i, origin.y), 2)
			r.modulate = Color(0.72, 0.86, 1.0)
			world.add_child(r)
			var r2 := _sprite(tex_town, int(T_ROOF_MID[i]), _c(origin.x + i, origin.y + 1), 2)
			r2.modulate = Color(0.72, 0.86, 1.0)
			world.add_child(r2)
			world.add_child(_sprite(tex_town, int(T_WALL[i]), _c(origin.x + i, origin.y + 2), 2))
		_blocker(TILE * 3 - 8, TILE - 6, _c(origin.x + 1, origin.y + 1))
		return
	var l := Label.new()
	l.text = "택지 %d" % num + ("  (내 영토)" if mine == num - 1 else "")
	l.position = _c(origin.x + 1, origin.y) + Vector2(-34, 0)
	l.add_theme_font_override("font", ui_font)
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.75) if mine == num - 1 else Color(0.92, 0.9, 0.8))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	l.z_index = 6
	world.add_child(l)


func _my_plot_slot() -> int:
	var p = _dict_of(boot.get("plot"))
	if p.is_empty():
		return -1
	return int(p.get("slot", -1))


func _my_plot_built() -> bool:
	var p = _dict_of(boot.get("plot"))
	return bool(p.get("built", false))


func _cave_entrance(cell: Vector2i) -> void:
	# 동굴 아치 — 어두운 입구 + 돌 테두리
	# 바위 언덕 (회색 비탈)
	for dy in [-2, -1]:
		for dx in [-1, 0, 1, 2]:
			var hill := ColorRect.new()
			hill.color = Color(0.42, 0.41, 0.44) if (dx + dy) % 2 == 0 else Color(0.47, 0.46, 0.48)
			hill.size = Vector2(TILE, TILE)
			hill.position = Vector2((cell.x + dx) * TILE, (cell.y + dy) * TILE)
			hill.z_index = 3
			world.add_child(hill)
	# 아치 테두리 (돌)
	var arch := ColorRect.new()
	arch.color = Color(0.58, 0.56, 0.52)
	arch.size = Vector2(TILE * 2, TILE * 2)
	arch.position = Vector2(cell.x * TILE - 6, cell.y * TILE - 26)
	arch.z_index = 4
	world.add_child(arch)
	# 입구 (어두운 구멍)
	var hole := ColorRect.new()
	hole.color = Color(0.06, 0.05, 0.08)
	hole.size = Vector2(TILE * 2 - 20, TILE + 14)
	hole.position = Vector2(cell.x * TILE + 4, cell.y * TILE - 6)
	hole.z_index = 5
	world.add_child(hole)

	var l := Label.new()
	l.text = "던전"
	l.position = _c(cell.x, cell.y) + Vector2(-14, -44)
	l.add_theme_font_override("font", ui_font)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(1, 0.72, 0.55))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.z_index = 6
	world.add_child(l)

	# 아치 2칸 폭 + 앞줄까지 입구 판정 (정확히 한 칸 밟기 어려워서 넓게 잡는다)
	for dx in [0, 1]:
		for dy in [0, -1]:
			var cc := Vector2i(cell.x + dx, cell.y + dy)
			if cc.x >= 0 and cc.y >= 0 and cc.x < MAP_W and cc.y < MAP_H:
				doors[cc] = {"to": "dungeon", "spawn": CAVE_SPAWN}


func _tree(cell: Vector2i, variant: int) -> void:
	var col := 4
	var s := Sprite2D.new()
	s.texture = tex_town
	s.region_enabled = true
	s.region_rect = Rect2(col * SRC, 0, SRC, SRC * 2)   # 위(캐노피) + 아래(줄기) 두 칸
	s.scale = Vector2(SCALE, SCALE)
	s.position = Vector2(cell.x * TILE + TILE / 2, cell.y * TILE)
	s.z_index = 3
	world.add_child(s)
	_blocker(26, 16, Vector2(cell.x * TILE + TILE / 2, cell.y * TILE + TILE - 12))


func _build_interior(kind: String) -> void:
	for y in ROOM_H:
		for x in ROOM_W:
			var wood := ColorRect.new()
			wood.color = Color(0.56, 0.40, 0.24) if (x + y) % 2 == 0 else Color(0.52, 0.36, 0.21)
			wood.size = Vector2(TILE, TILE)
			wood.position = Vector2(x * TILE, y * TILE)
			wood.z_index = -10
			world.add_child(wood)
	# 벽 — 창문/벽/창문 순으로 깔아 집 안처럼 보이게
	for x in ROOM_W:
		var wtile: int = 0 if x % 2 == 0 else 1
		world.add_child(_sprite(tex_town, int(T_WALL[wtile]), _c(x, 0), 1))
		_blocker(TILE, TILE, _c(x, 0))
	# 카운터(집기)
	for x in range(2, 5):
		var counter := ColorRect.new()
		counter.color = Color(0.38, 0.24, 0.14)
		counter.size = Vector2(TILE - 6, 18)
		counter.position = Vector2(x * TILE + 3, 4 * TILE + 22)
		counter.z_index = 1
		world.add_child(counter)
	for y in ROOM_H:
		_blocker(TILE, TILE, _c(0, y))
		_blocker(TILE, TILE, _c(ROOM_W - 1, y))

	# NPC
	var info := _npc_info(kind)
	_add_station(Vector2i(6, 3), int(info[0]), info[1], str(info[2]), kind)

	# 안내 문구
	var l := Label.new()
	l.text = str(info[2]) + "의 집 - 문 앞에서 E"
	l.position = _c(6, 1) + Vector2(-72, 0)
	l.add_theme_font_override("font", ui_font)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.z_index = 6
	world.add_child(l)

	# 출구
	var exit_cell := Vector2i(6, ROOM_H - 1)
	var door := ColorRect.new()
	door.color = Color(0.24, 0.14, 0.07)
	door.size = Vector2(TILE - 8, TILE - 12)
	door.position = Vector2(exit_cell.x * TILE + 4, exit_cell.y * TILE + 8)
	door.z_index = 1
	world.add_child(door)
	doors[exit_cell] = {"to": "town", "spawn": return_cell}


func _build_sea() -> void:
	# 사방이 바다 — 가운데에 배 한 척, 운전대에서 상호작용하면 마을로
	for y in 11:
		for x in 17:
			var w := ColorRect.new()
			w.color = Color(0.13, 0.35, 0.62) if (x + y) % 2 == 0 else Color(0.16, 0.40, 0.68)
			w.size = Vector2(TILE, TILE)
			w.position = Vector2(x * TILE, y * TILE)
			w.z_index = -10
			world.add_child(w)
	# 물결
	for i in 26:
		var chip := ColorRect.new()
		chip.color = Color(0.45, 0.68, 0.90, 0.55)
		chip.size = Vector2(18, 4)
		chip.position = Vector2(rng.randi_range(0, 17 * TILE), rng.randi_range(0, 11 * TILE))
		chip.z_index = -9
		world.add_child(chip)

	# 배 — 8비트 탑다운 목선 (뾰족한 앞머리 + 갑판 + 돛대 + 선실)
	var b := sea_boat
	var bx := b.position.x
	var by := b.position.y

	# 물 위 그림자
	var sh := ColorRect.new()
	sh.color = Color(0.05, 0.15, 0.30, 0.45)
	sh.size = Vector2((b.size.x + 1) * TILE, (b.size.y + 1) * TILE)
	sh.position = Vector2((bx - 1) * TILE + 8, (by - 1) * TILE + 10)
	sh.z_index = -3
	world.add_child(sh)

	# 뱃머리(위쪽 뾰족) — 폭 2칸
	for i in 2:
		var bow := ColorRect.new()
		bow.color = Color(0.58, 0.40, 0.22)
		bow.size = Vector2(TILE, TILE / 2)
		bow.position = Vector2((bx + 1 + i) * TILE, (by - 1) * TILE + TILE / 2)
		bow.z_index = -1
		world.add_child(bow)

	# 선체
	for y in range(by, by + b.size.y):
		for x in range(bx, bx + b.size.x):
			var plank := ColorRect.new()
			plank.color = Color(0.56, 0.39, 0.22) if (x + y) % 2 == 0 else Color(0.50, 0.34, 0.19)
			plank.size = Vector2(TILE, TILE)
			plank.position = Vector2(x * TILE, y * TILE)
			plank.z_index = -2
			world.add_child(plank)
			# 판자 이음선
			var seam := ColorRect.new()
			seam.color = Color(0.36, 0.23, 0.12, 0.55)
			seam.size = Vector2(TILE, 2)
			seam.position = Vector2(x * TILE, y * TILE + TILE / 2)
			seam.z_index = -1
			world.add_child(seam)

	# 난간(짙은 테두리)
	for y in range(by, by + b.size.y):
		for x in [bx, bx + b.size.x - 1]:
			var rail := ColorRect.new()
			rail.color = Color(0.33, 0.20, 0.10)
			rail.size = Vector2(8, TILE)
			rail.position = Vector2(x * TILE + (0 if x == bx else TILE - 8), y * TILE)
			rail.z_index = 1
			world.add_child(rail)
	for x in range(bx, bx + b.size.x):
		var rail2 := ColorRect.new()
		rail2.color = Color(0.33, 0.20, 0.10)
		rail2.size = Vector2(TILE, 8)
		rail2.position = Vector2(x * TILE, (by + b.size.y - 1) * TILE + TILE - 8)
		rail2.z_index = 1
		world.add_child(rail2)

	# 돛대 + 돛 (가운데)
	var mast := ColorRect.new()
	mast.color = Color(0.38, 0.25, 0.12)
	mast.size = Vector2(8, 92)
	mast.position = Vector2((bx + 2) * TILE + 28, (by + 1) * TILE - 20)
	mast.z_index = 2
	world.add_child(mast)
	var sail := ColorRect.new()
	sail.color = Color(0.93, 0.90, 0.82)
	sail.size = Vector2(46, 56)
	sail.position = Vector2((bx + 2) * TILE - 8, (by + 1) * TILE - 8)
	sail.z_index = 2
	world.add_child(sail)
	var sail_shade := ColorRect.new()
	sail_shade.color = Color(0.80, 0.76, 0.66)
	sail_shade.size = Vector2(10, 56)
	sail_shade.position = Vector2((bx + 2) * TILE + 28, (by + 1) * TILE - 8)
	sail_shade.z_index = 3
	world.add_child(sail_shade)

	# 선실 (뒤쪽)
	var cabin := ColorRect.new()
	cabin.color = Color(0.62, 0.45, 0.26)
	cabin.size = Vector2(TILE * 2 - 6, TILE - 8)
	cabin.position = Vector2(bx * TILE + 6, (by + 2) * TILE + 4)
	cabin.z_index = 2
	world.add_child(cabin)
	var cabin_roof := ColorRect.new()
	cabin_roof.color = Color(0.74, 0.56, 0.32)
	cabin_roof.size = Vector2(TILE * 2 - 6, 12)
	cabin_roof.position = Vector2(bx * TILE + 6, (by + 2) * TILE + 4)
	cabin_roof.z_index = 3
	world.add_child(cabin_roof)

	# 운전대 (키)
	var wheel := ColorRect.new()
	wheel.color = Color(0.75, 0.62, 0.30)
	wheel.size = Vector2(26, 26)
	wheel.position = Vector2(sea_wheel.x * TILE + TILE / 2 - 13, sea_wheel.y * TILE + TILE / 2 - 13)
	wheel.z_index = 3
	world.add_child(wheel)
	var wheel_l := Label.new()
	wheel_l.text = "운전대"
	wheel_l.position = _c(sea_wheel.x, sea_wheel.y) + Vector2(-24, -46)
	wheel_l.add_theme_font_override("font", ui_font)
	wheel_l.add_theme_font_size_override("font_size", 10)
	wheel_l.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	wheel_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	wheel_l.add_theme_constant_override("outline_size", 4)
	wheel_l.z_index = 6
	world.add_child(wheel_l)
	stations.append({"cell": sea_wheel, "kind": "wheel"})

	var t := Label.new()
	t.text = "바다 - 운전대에서 돌아가기"
	t.position = _c(8, 2) + Vector2(-70, 0)
	t.add_theme_font_override("font", ui_font)
	t.add_theme_font_size_override("font_size", 11)
	t.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	t.add_theme_constant_override("outline_size", 4)
	t.z_index = 6
	world.add_child(t)



func _ltr(l: Label) -> Label:
	l.text_direction = Control.TEXT_DIRECTION_LTR
	return l

func _tile(idx: int, cell: Vector2i, z: int = 0) -> void:
	# Tiny Dungeon 타일시트(16px, 12열)에서 한 칸을 그린다
	var s := Sprite2D.new()
	s.texture = tex_dungeon
	s.region_enabled = true
	s.region_rect = Rect2((idx % 12) * SRC, (idx / 12) * SRC, SRC, SRC)
	s.centered = false
	s.scale = Vector2(SCALE, SCALE)
	s.position = Vector2(cell.x * TILE, cell.y * TILE)
	s.z_index = z
	world.add_child(s)


func _dun_floor_at(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= DUN_W or y >= DUN_H:
		return false
	return dun_grid[y][x] == 0


func _build_gather_nodes() -> void:
	# 던전 안 광맥(rock) · 약초(forage) 노드를 그린다.
	# 서버 노드 좌표는 던전 그리드(1..9, 1..7) 기준이다.
	var scope := str(dun_floor)
	var payload: Dictionary = _dict_of(boot.get("mine"))
	if str(payload.get("scope", "")) != scope:
		payload = _dict_of(boot.get("gather"))
	var nodes: Array = payload.get("nodes", [])
	for n in nodes:
		var nd: Dictionary = _dict_of(n)
		if str(nd.get("scope", scope)) not in [scope, "town"]:
			continue
		var gx := int(nd.get("x", 1))
		var gy := int(nd.get("y", 1))
		# 던전 그리드 → 화면 타일 (DUN_W=11, DUN_H=9 가정: 1칸 여백)
		var px := gx * TILE
		var py := gy * TILE
		var is_rock := str(nd.get("kind", "")) == "rock"
		var box := ColorRect.new()
		box.size = Vector2(TILE - 10, TILE - 10)
		box.position = Vector2(px + 5, py + 5)
		box.z_index = 1
		box.color = Color(0.45, 0.45, 0.50) if is_rock else Color(0.30, 0.60, 0.30)
		if not bool(nd.get("can", true)):
			box.color = Color(0.40, 0.30, 0.30)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_nb.add_child(box)
		var lbl := Label.new()
		lbl.text = str(nd.get("name", ""))
		lbl.position = Vector2(px - 10, py - 14)
		lbl.size = Vector2(TILE + 20, 16)
		lbl.add_theme_font_override("font", ui_font)
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", Color(1, 0.96, 0.85))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.z_index = 2
		world.add_child(lbl)


func _build_dungeon() -> void:
	monsters.clear()
	lava_cells.clear()
	_gen_dungeon(dun_floor)

	# 바닥/벽 — Tiny Dungeon 타일
	for y in DUN_H:
		for x in DUN_W:
			var cell := Vector2i(x, y)
			var void_r := ColorRect.new()
			void_r.color = Color(0.23, 0.09, 0.08)
			void_r.size = Vector2(TILE, TILE)
			void_r.position = Vector2(x * TILE, y * TILE)
			void_r.z_index = -14
			world.add_child(void_r)
			if dun_grid[y][x] == 1:
				# 벽은 위/아래로 바닥과 맞닿은 칸에만 '가로 석재 바'로 그린다
				var touch := _dun_floor_at(x, y + 1) or _dun_floor_at(x, y - 1) 					or _dun_floor_at(x + 1, y) or _dun_floor_at(x - 1, y)
				if touch:
					# 이음선 없는 벽: 몸통 + 상단 캡 + 하단 그림자 + 벽돌선
					var body := ColorRect.new()
					body.color = Color(0.41, 0.46, 0.55)
					body.size = Vector2(TILE, TILE)
					body.position = Vector2(x * TILE, y * TILE)
					body.z_index = -8
					world.add_child(body)
					var cap := ColorRect.new()
					cap.color = Color(0.63, 0.67, 0.74)
					cap.size = Vector2(TILE, 7)
					cap.position = Vector2(x * TILE, y * TILE)
					cap.z_index = 1
					world.add_child(cap)
					var sh := ColorRect.new()
					sh.color = Color(0.13, 0.07, 0.06, 0.9)
					sh.size = Vector2(TILE, 11)
					sh.position = Vector2(x * TILE, y * TILE + TILE - 11)
					sh.z_index = 1
					world.add_child(sh)
					# 벽돌 가로선 (칸 경계가 아니라 8px 주기)
					for b in 3:
						var ln := ColorRect.new()
						ln.color = Color(0.30, 0.34, 0.42, 0.55)
						ln.size = Vector2(TILE, 2)
						ln.position = Vector2(x * TILE, y * TILE + 14 + b * 14)
						ln.z_index = 0
						world.add_child(ln)
					if (x * 5 + y * 7) % 19 == 0:
						_tile(29, cell, 2)
				_blocker(TILE, TILE, _c(x, y))
			else:
				_tile(49 if (x + y) % 2 == 0 else 50, cell, -10)
				var d := (x * 7 + y * 13) % 67
				if d == 0:
					_tile(43, cell, -9)
				elif d == 5:
					_tile(92, cell, -2)
				elif d == 11:
					_tile(121, cell, -2)

	# 채광·채집 노드 (바닥 위에 그린다)
	_build_gather_nodes()

	# 층 표시
	var title := Label.new()
	title.text = "던전 B%dF" % dun_floor
	title.position = _c(2, 1) + Vector2(-30, -6)
	title.add_theme_font_override("font", ui_font)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.6))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	title.add_theme_constant_override("outline_size", 5)
	title.z_index = 8
	world.add_child(title)

	# 계단 — 위(올라가기) / 아래(내려가기)
	_dungeon_stairs(dun_stairs_up, true)
	_dungeon_stairs(dun_stairs_down, false)

	# 용암 (5층부터)
	if dun_floor >= 5:
		var lava_start := Vector2i(DUN_W - 5, DUN_H - 4)
		for ly in range(lava_start.y, lava_start.y + 2):
			for lx in range(lava_start.x, lava_start.x + 3):
				if dun_grid[ly][lx] == 1:
					continue
				lava_cells.append(Vector2i(lx, ly))
				var lv := ColorRect.new()
				lv.color = Color(0.92, 0.35, 0.10) if (lx + ly) % 2 == 0 else Color(0.98, 0.52, 0.12)
				lv.size = Vector2(TILE, TILE)
				lv.position = Vector2(lx * TILE, ly * TILE)
				lv.z_index = -9
				world.add_child(lv)

	# 몬스터 — 층이 깊을수록 늘어난다
	var mon_tiles := [108, 121, 122, 120, 124, 109]
	var count := mini(2 + dun_floor / 2, 6)
	var spawn_cells := _dungeon_monster_cells(count)
	for i in spawn_cells.size():
		var mc: Vector2i = spawn_cells[i]
		var sprite := _sprite(tex_dungeon, int(mon_tiles[i % mon_tiles.size()]), _c(mc.x, mc.y), 3)
		world.add_child(sprite)
		var tag := Label.new()
		tag.text = "몬스터"
		tag.position = _c(mc.x, mc.y) + Vector2(-20, -46)
		tag.add_theme_font_override("font", ui_font)
		tag.add_theme_font_size_override("font_size", 9)
		tag.add_theme_color_override("font_color", Color(1, 0.72, 0.72))
		tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		tag.add_theme_constant_override("outline_size", 4)
		tag.z_index = 6
		world.add_child(tag)
		monsters.append({
			"node": sprite,
			"tag": tag,
			"home": Vector2(mc.x * TILE + TILE / 2, mc.y * TILE + TILE / 2),
			"pos": Vector2(mc.x * TILE + TILE / 2, mc.y * TILE + TILE / 2),
			"alive": true,
			"respawn_at": 0.0,
			"dead_t": 0.0,
			"wander": Vector2.ZERO,
			"wander_t": 0.0,
		})


func _gen_dungeon(floor_num: int) -> void:
	# 뱀형(serpentine) 복도: 가로 복도 4줄을 좌/우 번갈아 연결 — 좁고 꼬불꼬불
	dun_grid = []
	for y in DUN_H:
		var row: Array = []
		for x in DUN_W:
			row.append(1)
		dun_grid.append(row)

	var bands: Array = [1, 5, 9, 13]
	for bi in bands.size():
		var by: int = bands[bi]
		for y in [by, by + 1]:
			for x in range(1, DUN_W - 1):
				dun_grid[y][x] = 0
		# 층마다 시작 방향을 바꿔 매번 다르게
		var shaft_x := 1 if (bi + floor_num) % 2 == 0 else DUN_W - 2
		if bi < bands.size() - 1:
			var next_by: int = bands[bi + 1]
			for y in range(by + 1, next_by + 2):
				if y < DUN_H - 1:
					dun_grid[y][shaft_x] = 0
					dun_grid[y][mini(shaft_x + 1, DUN_W - 2)] = 0

	# 막다른 곁길(짧은 stub)을 몇 개 붙여 미로 느낌을 준다 — 세로로 끝까지 뚫어 체커판이 되지 않게
	for i in range(3 + floor_num % 3):
		var px: int = 3 + (i * 4 + floor_num * 3) % (DUN_W - 6)
		var by: int = bands[(i + floor_num) % bands.size()]
		var up_dir := (i % 2 == 0)
		for k in range(2):
			var yy: int = (by - 1 - k) if up_dir else (by + 2 + k)
			if yy <= 0 or yy >= DUN_H - 1:
				break
			if dun_grid[yy][px] == 1:
				dun_grid[yy][px] = 0
				if px + 1 < DUN_W - 1:
					dun_grid[yy][px + 1] = 0

	var start_dir := (floor_num % 2 == 0)
	dun_stairs_up = Vector2i(1 if start_dir else DUN_W - 2, 1)
	dun_stairs_down = Vector2i(DUN_W - 2 if start_dir else 1, DUN_H - 2)
	for c in [dun_stairs_up, dun_stairs_down]:
		dun_grid[c.y][c.x] = 0


func _dungeon_monster_cells(count: int) -> Array:
	var out: Array = []
	var tries := 0
	while out.size() < count and tries < 200:
		tries += 1
		var x := rng.randi_range(2, DUN_W - 3)
		var y := rng.randi_range(2, DUN_H - 3)
		if dun_grid[y][x] != 0:
			continue
		var cell := Vector2i(x, y)
		if cell == dun_stairs_up or cell == dun_stairs_down:
			continue
		var too_close := false
		for o in out:
			if absi(o.x - x) + absi(o.y - y) < 3:
				too_close = true
				break
		if too_close:
			continue
		out.append(cell)
	return out


func _dungeon_stairs(cell: Vector2i, up: bool) -> void:
	if up:
		_tile(67, cell, 1)       # 사다리
	else:
		_tile(82, cell, 1)       # 구덩이
	var l := Label.new()
	l.text = "올라가기" if up else ("내려가기" if dun_floor < DUN_MAX else "탈출")
	l.position = _c(cell.x, cell.y) + Vector2(-26, -46)
	l.add_theme_font_override("font", ui_font)
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0) if up else Color(1, 0.9, 0.6))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 4)
	l.z_index = 8
	world.add_child(l)
	doors[cell] = {"to": "stairs_up" if up else "stairs_down", "spawn": Vector2i(0, 0)}


func _monster_tick(delta: float) -> void:
	if scene_id != "dungeon":
		return
	if dun_hit_cool > 0.0:
		dun_hit_cool -= delta
	var ppos := player.position
	for m in monsters:
		if not m["alive"]:
			# 리스폰 대기
			if Time.get_ticks_msec() / 1000.0 >= float(m["respawn_at"]):
				m["alive"] = true
				m["pos"] = m["home"]
				(m["node"] as Sprite2D).modulate = Color(1, 1, 1, 1)
				(m["tag"] as Label).visible = true
			continue
		var mpos: Vector2 = m["pos"]
		var d := ppos.distance_to(mpos)
		if d < TILE * 4.5:
			# 추격
			var dir := (ppos - mpos).normalized()
			var stepv := dir * 92.0 * delta
			if absf(dir.x) > absf(dir.y):
				stepv = Vector2(signf(dir.x) * 92.0 * delta, 0)
			else:
				stepv = Vector2(0, signf(dir.y) * 92.0 * delta)
			var np := mpos + stepv
			if _dungeon_walkable(np):
				m["pos"] = np
			if d < TILE * 1.15 and dun_hit_cool <= 0.0 and not panel_open:
				dun_hit_cool = 2.0
				_dungeon_enter()
		else:
			# 배회
			m["wander_t"] = float(m["wander_t"]) - delta
			if float(m["wander_t"]) <= 0.0:
				m["wander_t"] = rng.randf_range(0.8, 2.0)
				var opts := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
				m["wander"] = opts[rng.randi_range(0, 3)]
			var wp: Vector2 = mpos + (m["wander"] as Vector2) * 28.0 * delta
			if _dungeon_walkable(wp):
				m["pos"] = wp
		var node: Sprite2D = m["node"]
		node.position = m["pos"]
		var tag: Label = m["tag"]
		tag.position = m["pos"] + Vector2(-20, -46)


func _kill_target_monster(drops: Array) -> void:
	var idx := dun_target
	if idx < 0 or idx >= monsters.size():
		return
	var m = monsters[idx]
	if not m["alive"]:
		return
	m["alive"] = false
	m["dead_t"] = Time.get_ticks_msec() / 1000.0
	m["respawn_at"] = m["dead_t"] + 25.0          # 25초 뒤 리스폰
	var node: Sprite2D = m["node"]
	node.modulate = Color(0.2, 0.2, 0.2, 0.25)
	(m["tag"] as Label).visible = false
	# 드랍 연출 — 아이템 조각이 잠깐 떠 있다 사라진다
	for i in maxi(1, drops.size()):
		var drop := ColorRect.new()
		drop.color = Color(1.0, 0.86, 0.35)
		drop.size = Vector2(12, 12)
		drop.position = (m["pos"] as Vector2) + Vector2(rng.randi_range(-26, 26), rng.randi_range(-18, 18))
		drop.z_index = 20
		world.add_child(drop)
		var tw := create_tween()
		tw.tween_property(drop, "modulate:a", 0.0, 1.4).set_delay(0.9)
		tw.tween_callback(func(): drop.queue_free())
	dun_target = -1


func _dungeon_walkable(pos: Vector2) -> bool:
	var cell := Vector2i(int(floor(pos.x / TILE)), int(floor(pos.y / TILE)))
	if cell.x < 0 or cell.y < 0 or cell.x >= DUN_W or cell.y >= DUN_H:
		return false
	return dun_grid[cell.y][cell.x] == 0


func _npc_info(kind: String) -> Array:
	match kind:
		"shop":
			return [T_MERCHANT, tex_farm, "상점"]
		"smith":
			return [T_SMITH, tex_dungeon, "대장간"]
		"cook":
			return [T_COOK, tex_dungeon, "요리"]
		"carpenter":
			return [T_SMITH, tex_farm, "목수"]
		_:
			return [T_FISHER, tex_dungeon, "낚시"]


func _add_station(cell: Vector2i, idx: int, tex: Texture2D, label: String, kind: String = "") -> void:
	var pos := _c(cell.x, cell.y)
	world.add_child(_sprite(tex, idx, pos, 2))
	var l := Label.new()
	l.text = label
	l.position = pos + Vector2(-24, -50)
	l.add_theme_font_override("font", ui_font)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(1, 0.96, 0.8))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.z_index = 5
	world.add_child(l)
	if kind != "":
		stations.append({"cell": cell, "kind": kind})


func _build_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.position = _c(TOWN_SPAWN.x, TOWN_SPAWN.y)
	player.z_index = 3
	player_sprite = _sprite(tex_farm, T_PLAYER, Vector2(0, -TILE / 2), 0)
	player.add_child(player_sprite)

	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(28, 18)
	cs.shape = r
	cs.position = Vector2(0, -8)
	player.add_child(cs)

	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = MAP_W * TILE
	cam.limit_bottom = MAP_H * TILE
	cam.position = Vector2(0, -TILE / 2)
	cam.zoom = Vector2(0.55, 0.55)
	player.add_child(cam)
	add_child(player)


func _physics_process(delta: float) -> void:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1
	if touch_dir != Vector2.ZERO:
		v = touch_dir

	moving = v.length() > 0.01 and not panel_open and not battle_open
	if moving:
		v = v.normalized()
		player.velocity = v * SPEED
		if absf(v.x) > absf(v.y):
			facing = "left" if v.x < 0 else "right"
		else:
			facing = "up" if v.y < 0 else "down"
	else:
		player.velocity = Vector2.ZERO
	player.move_and_slide()

	player.position.x = clampf(player.position.x, TILE * 0.7, MAP_W * TILE - TILE * 0.7)
	player.position.y = clampf(player.position.y, TILE * 0.7, MAP_H * TILE - TILE * 0.7)

	walk_t += delta
	var bob := 0.0
	if moving:
		bob = absf(sin(walk_t * 9.0)) * 6.0
	player_sprite.position.y = -TILE / 2 - bob
	player_sprite.flip_h = facing == "left"
	_monster_tick(delta)
	if door_lock > 0.0:
		door_lock -= delta
	elif not panel_open:
		var cell := _player_cell()
		if doors.has(cell):
			var d: Dictionary = doors[cell]
			var to := str(d.get("to", "town"))
			if to == "stairs_down" or to == "stairs_up":
				_use_stairs(to == "stairs_down")
				return
			if to != "town":
				# 방에 들어갈 때 그 문 바로 앞 칸을 복귀 지점으로 기억한다
				return_cell = cell + Vector2i(0, 1)
			_enter_scene(to, d.get("spawn", TOWN_SPAWN))
	_net_tick(delta)


func _use_stairs(down: bool) -> void:
	if down:
		if dun_floor >= DUN_MAX:
			_toast("마지막 층입니다")
			return
		dun_floor += 1
	else:
		if dun_floor <= 1:
			_enter_scene("town", return_cell)
			door_lock = 0.9
			return
		dun_floor -= 1
	door_lock = 1.1
	monsters.clear()
	_fade_to(func():
		_build_scene()
		player.position = _c(dun_stairs_up.x if not down else 1, dun_stairs_up.y if not down else 1)
		player.position = _c(dun_stairs_down.x, dun_stairs_down.y) if down else _c(dun_stairs_up.x, dun_stairs_up.y + 2)
		_update_hud())
	_toast("B%dF" % dun_floor)


func _enter_scene(id: String, spawn_cell: Vector2i) -> void:
	if id == scene_id:
		return
	# 마을로 돌아올 때는 문 바로 앞 칸으로 (문 위에서 다시 트리거되지 않게)
	if id == "town":
		return_cell = spawn_cell
	scene_id = id
	player.velocity = Vector2.ZERO
	door_lock = 0.9
	_fade_to(func():
		_build_scene()
		player.position = _c(spawn_cell.x, spawn_cell.y)
		_update_hud())
	match id:
		"town":
			_toast("마을")
		"dungeon":
			dun_floor = 1
			_toast("던전 B1F - 몬스터를 피해 내려가세요")
		_:
			_toast(_bare(str(_npc_info(id)[2])) + "의 집")


func _process(delta: float) -> void:
	_poll_pending()
	_npc_tick(delta)
	_dlg_tick(delta)
	_minimap_tick(delta)
	_ltr_fix(delta)
	_fish_tick(delta)
	if OS.has_feature("web"):
		var pc := _player_cell()
		JavaScriptBridge.eval("document.title='%s HA.NA Farm [%s %d,%d] fish=%s ct=%.2f wait=%.2f ui=%s'" % [BUILD_TAG, 
			scene_id, pc.x, pc.y, fish_state, cast_t, fish_wait,
			"1" if (fish_ui != null and fish_ui.visible) else "0"])
	if _clock_text() != _last_clock:
		_last_clock = _clock_text()
		_update_hud()
	if toast_t > 0.0:
		toast_t -= delta
		toast_label.modulate.a = clampf(toast_t / 0.6, 0.0, 1.0)
		if toast_t <= 0.0:
			toast_label.text = ""
	if panel_open and panel_mode == "fish" and fish_state == "casting":
		fish_marker += fish_dir * delta * 0.85
		if fish_marker >= 1.0:
			fish_marker = 1.0
			fish_dir = -1.0
		elif fish_marker <= 0.0:
			fish_marker = 0.0
			fish_dir = 1.0
		var mk: ColorRect = panel.get_node_or_null("Marker")
		if mk != null:
			mk.position.x = 24 + fish_marker * (panel.size.x - 60)


# ──────────────────────────────────────────── 입력
func _input(event: InputEvent) -> void:
	if dlg_layer != null and dlg_layer.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
				_advance_dialog()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_advance_dialog()
		elif event is InputEventScreenTouch and event.pressed:
			_advance_dialog()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if panel_open:
				_close_panel()
			return
		if event.keycode == KEY_E:
			if panel_open:
				_close_panel()
			else:
				_interact()
			return
		if event.keycode == KEY_F and not panel_open:
			if _fish_location() != "":
				if int(_dict_of(boot.get("stamina")).get("cur", 0)) <= 0:
					_open_panel("fish")
				else:
					_fish_cast()
			return
		if event.keycode == KEY_M:
			# 전체 지도 보기 토글 (QA/스크린샷용)
			if cam.zoom.x < 0.5:
				cam.zoom = Vector2(0.55, 0.55)
			else:
				cam.zoom = Vector2(0.3, 0.3)
			return
		if event.keycode == KEY_K and not panel_open:
			# 숙련도 창 열기
			_open_panel("skills")
			return
		if event.keycode == KEY_G and not panel_open:
			# 채집 / 채광 창 (던전에서는 채광)
			_open_panel("mine" if scene_id == "dungeon" else "gather")
			return
		if event.keycode == KEY_SPACE:
			if panel_open:
				return      # 낚시 중에는 SPACE 를 누르고 있는 것 자체가 입력
			_interact()


func _player_cell() -> Vector2i:
	return Vector2i(int(floor(player.position.x / TILE)), int(floor(player.position.y / TILE)))


func _npc_talk(kind: String) -> void:
	var info: Array = _npc_info(kind)
	var lines: Array = NPC_LINES.get(kind, ["...반갑습니다."])
	var panel_key: String = kind
	if kind == "smith":
		panel_key = "strengthen"
	elif kind == "fish_sp":
		panel_key = "fish"
	elif kind == "carpenter":
		panel_key = "plot"
	elif kind == "farm":
		panel_key = "farm"
	_say(lines, str(info[2]), info[1], int(info[0]), func(): _open_panel(panel_key))


const NPC_LINES := {
	"shop": ["어서 오게, 여행자.", "여기서 쓸 만한 물건을 팔고 있지.", "필요한 게 있으면 한번 둘러보게나."],
	"smith": ["크윽... 쇠는 언제나 뜨겁지.", "강화할 건가? 실패하면 부서질 각오는 되어 있겠지.", "가져온 것부터 보자고."],
	"cook": ["냠냠... 아, 손님이시구나!", "재료 3개를 골라 주면 맛있는 요리를 해줄게.", "수익도 쏠쏠하다구."],
	"fish": ["물좋은 날이군요.", "낚시는 인내와 타이밍이죠.", "선착장 끝에 배를 두었으니, 더 깊은 물로 나가봐요."],
	"carpenter": ["무슨 집을 짓고 싶으신가?", "내가 도와드리지. 다만...", "영토가 있어야 하고, 던전에서 실력도 보여줘야 하지."],
}


func _enter_sea() -> void:
	_say(["배에 올랐다.", "바다로 나가 보자."], "낚시꾼", tex_dungeon, T_FISHER, func():
		scene_id = "sea"
		door_lock = 1.2
		_fade_to(func():
			_build_scene()
			player.position = _c(8, 7)      # 갑판 위
			_update_hud())
		_toast("바다 - 운전대로 돌아가기"))


func _leave_sea() -> void:
	_say(["선착장으로 돌아갑니다."], "낚시꾼", tex_dungeon, T_FISHER, func():
		scene_id = "town"
		door_lock = 1.2
		_fade_to(func():
			_build_scene()
			player.position = _c(PIER_X, PIER_Y1)
			_update_hud()))


func _gather_nearest(p: Vector2i) -> bool:
	# 내 위치 반경 1.5 안의 채집/채광 노드를 찾아 캔다. 캤으면 true.
	var scope := "town" if scene_id == "town" else str(dun_floor)
	var key := "gather" if scope == "town" else "mine"
	var payload: Dictionary = _dict_of(boot.get(key))
	if str(payload.get("scope", "")) != scope and scope != "town":
		payload = _dict_of(boot.get("gather"))
	var best: Dictionary = {}
	var best_d := 999
	for n in payload.get("nodes", []):
		var nd: Dictionary = _dict_of(n)
		var nx := int(nd.get("x", -99))
		var ny := int(nd.get("y", -99))
		var d := absi(nx - p.x) + absi(ny - p.y)
		if d < best_d and d <= 2:
			best_d = d
			best = nd
	if best.is_empty():
		return false
	_api("gather", {"x": int(best.get("x", 0)), "y": int(best.get("y", 0)),
		"kind": str(best.get("kind", "")), "scope": scope})
	return true


func _interact() -> void:
	var p := _player_cell()
	# 마을을 돌아다니는 NPC가 바로 옆에 있으면 그 NPC와 대화한다
	var npc := _nearest_npc()
	if not npc.is_empty():
		_npc_talk(str(npc.get("kind", "")))
		return
	# 가까운 채집/채광 노드가 있으면 먼저 캔다
	if _gather_nearest(p):
		return
	for st in stations:
		if _near(p, st["cell"], 1):
			var kind := str(st["kind"])
			if kind == "monster":
				_dungeon_enter()
			elif kind == "boat":
				_enter_sea()
			elif kind == "wheel":
				_leave_sea()
			else:
				_npc_talk(kind)
			return
	if _fish_location() != "":
		# ST가 없으면 충전할 수 있게 패널을, 있으면 바로 낚싯대를 던진다
		if int(_dict_of(boot.get("stamina")).get("cur", 0)) <= 0:
			_open_panel("fish")
		else:
			_fish_cast()
		return
	_toast("NPC에게 다가가 E 또는 SPACE")


# ──────────────────────────────────────────── HTTP
func _init_http() -> void:
	if OS.has_feature("web"):
		return                     # 웹은 fetch() 사용
	http_boot = HTTPRequest.new()
	http_boot.timeout = 15.0
	add_child(http_boot)
	http_boot.request_completed.connect(_on_boot_done)
	http_act = HTTPRequest.new()
	http_act.timeout = 20.0
	add_child(http_act)
	http_act.request_completed.connect(_on_act_done)


# ── 웹: 쿠키 포함 fetch (HTTPRequest 는 세션 쿠키를 안 보냄) ──
func _js_fetch(path: String, method: String, body: String, cb: Callable) -> void:
	if not OS.has_feature("web"):
		if method == "GET":
			http_boot.request(_base_url() + path)
		else:
			http_act.request(_base_url() + path, ["Content-Type: application/json"],
				HTTPClient.METHOD_POST, body)
		return
	var key := "apir_%d" % rng.randi_range(100000, 999999)
	var init := "{credentials:'include',cache:'no-store',method:'" + method + "'"
	if body != "":
		init += ",headers:{'Content-Type':'application/json'},body:" + JSON.stringify(body)
	init += "}"
	var js := "window.%s=null;fetch('%s',%s).then(async r=>{const t=await r.text();window.%s={code:r.status,body:t}}).catch(e=>window.%s={code:-1,body:''+e})" % [key, path, init, key, key]
	JavaScriptBridge.eval(js)
	pending.append({"key": key, "cb": cb})


func _poll_pending() -> void:
	if pending.is_empty() or not OS.has_feature("web"):
		return
	for p in pending.duplicate():
		var raw = JavaScriptBridge.eval("JSON.stringify(window.%s)" % String(p["key"]))
		if raw == null:
			continue
		var txt := str(raw)
		if txt == "null" or txt == "":
			continue
		pending.erase(p)
		var wrap = JSON.parse_string(txt)
		if typeof(wrap) != TYPE_DICTIONARY:
			continue
		var code := int(wrap.get("code", 0))
		var data = JSON.parse_string(str(wrap.get("body", "")))
		if typeof(data) != TYPE_DICTIONARY:
			data = {"ok": false, "error": "응답 파싱 실패"}
		p["cb"].call(code, data)


func _base_url() -> String:
	if OS.has_feature("web"):
		var host: String = str(JavaScriptBridge.eval("location.host", true))
		var proto := "https" if str(JavaScriptBridge.eval("location.protocol", true)) == "https:" else "http"
		return "%s://%s" % [proto, host]
	return "http://127.0.0.1:8000"


func _fetch_boot() -> void:
	_js_fetch("/api/game/bootstrap", "GET", "", _on_boot_data)


func _on_boot_data(code: int, data: Dictionary) -> void:
	if code == 401:
		boot = {}
		panel_msg = "로그인이 필요합니다"
	elif code == 200 and data.get("ok", false):
		boot = data
		panel_msg = ""
		_update_hud()
		# bootstrap 이 늦게 도착해도 월드(농장 밭·채집 노드 등)가 반영되도록 재구성한다
		_build_scene()
	else:
		panel_msg = str(data.get("error", "불러오기 실패"))
	if panel_open:
		_render_panel()
	if toast_t <= 0.0 and code == 200:
		pass


func _api(path: String, payload: Dictionary) -> void:
	var url := "/dashboard/%s/api/minigame/%s" % [str(boot.get("guild_id", "")), path]
	_js_fetch(url, "POST", JSON.stringify(payload), _on_act_data)


func _on_act_data(code: int, data: Dictionary) -> void:
	if code == 401:
		_toast("로그인이 필요합니다")
		return
	_toast(_act_message(panel_mode, data))
	_fetch_boot()


func _on_boot_done(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if code == 401:
		boot = {}
		panel_msg = "로그인이 필요합니다"
	elif code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) == TYPE_DICTIONARY and data.get("ok", false):
			boot = data
			panel_msg = ""
			_update_hud()
	if panel_open:
		_render_panel()


func _on_act_done(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		data = {}
	_toast(_act_message(panel_mode, data))
	_fetch_boot()


func _act_message(mode: String, d: Dictionary) -> String:
	if not d.get("ok", false):
		return "실패: " + str(d.get("error", "알 수 없음"))
	if mode == "strengthen":
		var res := str(d.get("result", ""))
		if res == "success":
			return "강화 성공! → Lv.%s" % str(d.get("level", ""))
		if res == "destroy":
			return "파괴… → Lv.%s" % str(d.get("level", ""))
		return "실패 → Lv.%s" % str(d.get("level", ""))
	if mode == "cook":
		return "요리 완성: " + str(_or(_or(d.get("item"), d.get("name")), "성공"))
	return "완료"


# ──────────────────────────────────────────── 패널 UI
func _build_panel() -> void:
	panel_layer = CanvasLayer.new()
	panel_layer.name = "Panel"
	add_child(panel_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_layer.add_child(dim)
	panel = Panel.new()
	panel.position = Vector2(96, 96)
	panel.size = Vector2(460, 308)
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = Vector2(230, 154)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.12, 0.08, 0.97)
	sb.border_color = Color(0.55, 0.40, 0.22)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	panel_layer.add_child(panel)


func _open_panel(mode: String) -> void:
	panel_mode = mode
	panel_open = true
	panel_msg = ""
	fish_state = "idle"
	cook_pick = false
	if panel_layer == null:
		_build_panel()
	panel_layer.visible = true
	panel.position = Vector2(96, 400)
	var tw := create_tween()
	tw.tween_property(panel, "position", Vector2(96, 96), 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if boot.is_empty():
		_fetch_boot()
	_render_panel()


func _close_panel() -> void:
	panel_open = false
	panel_mode = ""
	fish_state = "idle"
	if panel_layer != null:
		panel_layer.visible = false


func _plabel(text: String, pos: Vector2, size: Vector2, fs: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_override("font", ui_font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	panel.add_child(l)
	return l


func _pbutton(text: String, pos: Vector2, size: Vector2, cb: Callable, fs: int = 12) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", ui_font)
	b.add_theme_font_size_override("font_size", fs)
	b.pressed.connect(cb)
	panel.add_child(b)
	return b


func _render_panel() -> void:
	# 패널을 열지 않은 상태(월드 낚시 등)에서 호출되면 아무 것도 하지 않는다.
	if panel == null or not panel_open:
		return
	for c in panel.get_children():
		c.queue_free()
	var titles := {"shop": "상점", "strengthen": "대장장이 - 강화", "cook": "요리",
		"fish": "낚시", "battle": "던전 전투", "plot": "목수 - 영토와 집", "farm": "농장",
		"skills": "숙련도", "gather": "채집", "mine": "채광"}
	_plabel(titles.get(panel_mode, ""), Vector2(14, 8), Vector2(240, 26), 17, Color(1, 0.92, 0.75))
	_pbutton("닫기", Vector2(392, 8), Vector2(56, 26), func(): _close_panel())

	if boot.is_empty():
		_plabel(panel_msg if panel_msg != "" else "불러오는 중...", Vector2(16, 100), Vector2(420, 24), 13,
			Color(1, 0.8, 0.6))
		if panel_msg == "로그인이 필요합니다":
			_pbutton("로그인 하러 가기", Vector2(150, 140), Vector2(160, 34), func():
				if OS.has_feature("web"):
					JavaScriptBridge.eval("window.location.href='/'", true), 13)
		return

	_plabel("XP " + _fmt(int(boot.get("xp", 0))), Vector2(250, 12), Vector2(180, 22), 13, Color(1, 0.85, 0.4))

	match panel_mode:
		"shop":
			_render_shop()
		"strengthen":
			_render_strengthen()
		"cook":
			_render_cook()
		"fish":
			_render_fish()
		"battle":
			_render_battle()
		"plot":
			_render_plot()
		"farm":
			_render_farm()
		"skills":
			_render_skills()
		"gather":
			_render_gather("town")
		"mine":
			_render_gather(str(dun_floor))


func _render_gather(scope: String) -> void:
	# 채집(마을) · 채광(던전) — 노드 목록에서 골라 캔다.
	var is_town := scope == "town"
	var key := "gather" if is_town else "mine"
	var payload: Dictionary = _dict_of(boot.get(key))
	var nodes: Array = payload.get("nodes", [])
	var en: Dictionary = _dict_of(payload.get("energy"))
	var lvs: Dictionary = _dict_of(payload.get("levels"))
	var lv_f := int(lvs.get("foraging", 0))
	var lv_m := int(lvs.get("mining", 0))
	var here := _player_cell()

	_plabel("채집 Lv.%d · 채광 Lv.%d · 실행력 %d/%d" % [
		lv_f, lv_m, int(en.get("cur", 0)), int(en.get("max", 20))],
		Vector2(16, 36), Vector2(330, 20), 12, Color(0.85, 0.92, 0.85))
	_plabel("내 위치 (%d,%d) — 노드를 클릭하면 캡니다" % [here.x, here.y],
		Vector2(16, 54), Vector2(330, 18), 10, Color(0.7, 0.85, 0.95))

	if nodes.is_empty():
		_plabel("이 지역에 노드가 없습니다. 하루를 보내면 다시 생깁니다.",
			Vector2(16, 80), Vector2(400, 20), 11, Color(1, 0.8, 0.6))
		return

	_plabel("노드", Vector2(16, 78), Vector2(120, 18), 11, Color(0.9, 0.85, 0.7))
	_plabel("필요", Vector2(232, 78), Vector2(50, 18), 10, Color(0.75, 0.78, 0.7))
	_plabel("가치", Vector2(286, 78), Vector2(60, 18), 10, Color(0.75, 0.78, 0.7))

	var shown := mini(7, nodes.size())
	for i in shown:
		var nd: Dictionary = _dict_of(nodes[i])
		var y := 98 + i * 30
		var is_rock := str(nd.get("kind", "")) == "rock"
		var can := bool(nd.get("can", true))
		var col := Color(0.92, 0.94, 0.88) if can else Color(0.65, 0.55, 0.5)
		_plabel("%s%s  (%d,%d)%s" % [
			str(nd.get("name", "?")),
			"" if int(nd.get("hits", 1)) <= 1 else " ×%d" % int(nd.get("hits", 1)),
			int(nd.get("x", 0)), int(nd.get("y", 0)),
			"  [범위 밖]" if not can else ""],
			Vector2(16, y + 4), Vector2(210, 20), 11, col)
		_plabel("%s%d" % ["채광" if is_rock else "채집", int(nd.get("req_level", 0))],
			Vector2(232, y + 4), Vector2(52, 20), 10, Color(0.8, 0.82, 0.75))
		_plabel("%s" % _fmt(int(nd.get("sell", 0))), Vector2(286, y + 4),
			Vector2(56, 20), 10, Color(1, 0.9, 0.6))
		var nx := int(nd.get("x", 0))
		var ny := int(nd.get("y", 0))
		var nk := str(nd.get("kind", ""))
		_pbutton("캐기" if is_rock else "따기", Vector2(346, y), Vector2(66, 26), func():
			_api("gather", {"x": nx, "y": ny, "kind": nk, "scope": scope}), 10)

	_plabel("※ 노드 옆에 서면 가까운 노드를 캡니다 (E키)",
		Vector2(16, 320), Vector2(400, 18), 9, Color(0.65, 0.72, 0.68))


func _render_farm() -> void:
	# 농사: 계절/일차/에너지 → 씨앗 목록 → 하루 보내기 → 출하 대기
	# 농사는 '내가 서 있는 타일'에서 동작한다(스타듀밸리와 동일).
	var here := _player_cell()
	farm_x = here.x
	farm_y = here.y
	var farm: Dictionary = _dict_of(boot.get("farm"))
	var sumo: Dictionary = _dict_of(farm.get("summary"))
	var en: Dictionary = _dict_of(farm.get("energy"))
	_plabel("%s %d일차 · 내 위치 (%d,%d)" % [
		str(farm.get("season_ko", "봄")), int(sumo.get("season_day", 1)), farm_x, farm_y],
		Vector2(16, 36), Vector2(340, 20), 13, Color(1, 0.9, 0.7))
	if not _is_farm_area(here):
		_plabel("밭 구역(%d,%d)~(%.0f,%.0f)으로 이동해야 경작할 수 있습니다." % [
			FARM_X0, FARM_Y0, FARM_X0 + FARM_W - 1, FARM_Y0 + FARM_H - 1],
			Vector2(16, 56), Vector2(410, 20), 11, Color(1, 0.75, 0.6))
	var tiles: Dictionary = _dict_of(farm.get("tiles"))
	var t: Dictionary = _dict_of(tiles.get("%d,%d" % [farm_x, farm_y]))
	_plabel("이 타일: %s%s" % [
		"경작됨" if bool(t.get("tilled", false)) else "잔디",
		" · 물 줌" if bool(t.get("watered", false)) else ""],
		Vector2(16, 74), Vector2(200, 20), 11, Color(0.85, 0.9, 0.75))
	_plabel("실행력 %d/%d · 수확가능 %d · 출하 %s XP" % [
		int(en.get("cur", 0)), int(en.get("max", 10)),
		int(sumo.get("ready", 0)), _fmt(int(sumo.get("pending_ship", 0)))],
		Vector2(196, 74), Vector2(240, 20), 11, Color(0.6, 0.9, 1.0))

	_pbutton("갈기", Vector2(16, 100), Vector2(72, 28), func():
		_api("farm/till", {"x": farm_x, "y": farm_y}), 12)
	_pbutton("물 주기", Vector2(94, 100), Vector2(80, 28), func():
		_api("farm/water", {"x": farm_x, "y": farm_y}), 12)
	_pbutton("수확", Vector2(180, 100), Vector2(72, 28), func():
		_api("farm/harvest", {"x": farm_x, "y": farm_y}), 12)

	var seeds: Array = farm.get("seeds", [])
	if seeds.is_empty():
		_plabel("이번 계절에 심을 씨앗이 없습니다.", Vector2(16, 136), Vector2(400, 22), 12,
			Color(1, 0.8, 0.6))
	else:
		_plabel("씨앗 (XP로 구매)", Vector2(16, 132), Vector2(200, 18), 11,
			Color(0.9, 0.85, 0.7))
		for i in mini(4, seeds.size()):
			var s: Dictionary = _dict_of(seeds[i])
			var y := 152 + i * 34
			_plabel("%s %sXP %d일 %sg" % [
				str(s.get("name", "?")), _fmt(int(s.get("seed_price", 0))),
				int(s.get("days", 1)), str(s.get("gold_per_day", 0))],
				Vector2(16, y + 4), Vector2(300, 22), 11, Color(0.9, 0.92, 0.85))
			_pbutton("심기", Vector2(322, y), Vector2(58, 26), func():
				_api("farm/plant", {"x": farm_x, "y": farm_y,
					"crop": str(s.get("key", ""))}), 11)

	_pbutton("하루 보내기", Vector2(16, 300), Vector2(120, 30), func():
		_api("farm/day", {}), 13)


func _render_skills() -> void:
	# 스타듀밸리식 5개 숙련도 — 레벨/XP 막대/직업 선택
	var sk: Dictionary = _dict_of(boot.get("skills"))
	if sk.is_empty():
		_plabel("숙련도 데이터를 불러오지 못했습니다.", Vector2(16, 60), Vector2(400, 22), 13,
			Color(1, 0.7, 0.6))
		return
	var order := ["farming", "foraging", "fishing", "mining", "combat"]
	for i in order.size():
		var key: String = order[i]
		var s: Dictionary = _dict_of(sk.get(key))
		var y := 46 + i * 48
		var lv := int(s.get("level", 0))
		_plabel("%s" % str(s.get("name", key)), Vector2(16, y), Vector2(56, 22), 14,
			Color(0.95, 0.92, 0.8))
		_plabel("Lv.%d" % lv, Vector2(74, y), Vector2(46, 22), 13, Color(1, 0.9, 0.55))
		# XP 막대
		var bar := ColorRect.new()
		bar.color = Color(0.12, 0.16, 0.22, 0.95)
		bar.position = Vector2(122, y + 5)
		bar.size = Vector2(160, 12)
		panel.add_child(bar)
		var ratio := clampf(float(s.get("ratio", 0.0)), 0.0, 1.0)
		var fill := ColorRect.new()
		fill.color = Color(0.55, 0.85, 0.45)
		fill.position = Vector2(122, y + 5)
		fill.size = Vector2(maxf(1.0, 160.0 * ratio), 12)
		panel.add_child(fill)
		var txt := "%d / %d" % [int(s.get("in_level", 0)), int(s.get("need", 0))]
		if lv >= 10:
			txt = "MAX"
		_plabel(txt, Vector2(288, y), Vector2(96, 22), 11, Color(0.85, 0.9, 0.8))
		# 직업 선택 버튼(5/10 레벨 도달 + 미선택)
		var profs: Array = s.get("professions", [])
		var choices: Array = s.get("choices", [])
		if not choices.is_empty():
			var lev := 10 if lv >= 10 else 5
			for j in mini(2, choices.size()):
				var c: Dictionary = _dict_of(choices[j])
				_pbutton(str(c.get("name", "선택")), Vector2(16 + j * 90, y + 22),
					Vector2(84, 22), func():
					_api("skills/profession", {"skill": key, "level": lev,
						"profession": str(c.get("id", ""))}), 10)
		elif not profs.is_empty():
			_plabel("직업: %s" % str(profs[0]), Vector2(16, y + 24), Vector2(200, 18), 10,
				Color(0.7, 0.85, 0.95))


func _render_shop() -> void:
	# 구매/판매 탭
	var tabs := [["buy", "구매"], ["sell", "판매"]]
	for i in tabs.size():
		var tk: String = tabs[i][0]
		var on_t: bool = shop_tab == tk
		var tb := _pbutton(tabs[i][1], Vector2(14 + i * 74, 40), Vector2(70, 26),
			func(): shop_tab = tk; _render_panel())
		tb.add_theme_color_override("font_color", Color(1, 0.9, 0.6) if on_t else Color(0.8, 0.78, 0.72))
	if shop_tab == "sell":
		_render_sell()
		return

	var cats := [["bait", "미끼"], ["material", "재료"], ["item", "아이템"]]
	for i in cats.size():
		var key: String = cats[i][0]
		var on := shop_cat == key
		var b := _pbutton(cats[i][1], Vector2(14 + i * 74 + 152, 40), Vector2(66, 26),
			func(): shop_cat = key; _render_panel())
		b.add_theme_color_override("font_color", Color(1, 0.9, 0.6) if on else Color(0.82, 0.78, 0.7))

	var shop_all: Dictionary = {}
	var sraw = boot.get("shop", {})
	if typeof(sraw) == TYPE_DICTIONARY:
		shop_all = sraw
	var items: Dictionary = {}
	if shop_all.has(shop_cat):
		var iv = shop_all[shop_cat]
		if typeof(iv) == TYPE_DICTIONARY:
			items = iv
	var owned: Dictionary = _dict_of(boot.get("owned"))
	var y := 76
	for key in items.keys():
		var it: Dictionary = items[key]
		var have := 0
		if shop_cat == "bait":
			have = int((_dict_of(owned.get("baits"))).get(key, 0))
		else:
			have = int((_dict_of(owned.get("inventory"))).get(key, 0))
		_plabel("%s  (보유 %d)" % [_bare(it.get("name", key)), have], Vector2(16, y), Vector2(240, 22), 12,
			Color(0.95, 0.93, 0.86))
		_plabel(_fmt(int(it.get("price", 0))) + " XP", Vector2(268, y), Vector2(90, 22), 12, Color(1, 0.84, 0.45))
		var k := str(key)
		_pbutton("구매", Vector2(366, y - 3), Vector2(76, 24), func(): _buy(k))
		y += 32
		if y > 268:
			break


func _render_sell() -> void:
	var rows: Array = []
	var raw_rows = boot.get("inventory_list", [])
	if typeof(raw_rows) == TYPE_ARRAY:
		rows = raw_rows
	var per := 5
	var pages: int = maxi(1, int(ceil(float(rows.size()) / float(per))))
	if sell_page >= pages:
		sell_page = pages - 1
	if sell_page < 0:
		sell_page = 0
	var start := sell_page * per
	var shown: Array = rows.slice(start, start + per)

	var total_n := 0
	var total_xp := 0
	for e in rows:
		var k := str(e.get("key", ""))
		var n := int(sell_qty.get(k, 0))
		total_n += n
		total_xp += n * int(e.get("price", 0))

	var y := 78
	if shown.is_empty():
		_plabel("판매할 아이템이 없습니다", Vector2(16, y), Vector2(300, 22), 12, Color(1, 0.8, 0.6))
	for e in shown:
		var key := str(e.get("key", ""))
		var have := int(e.get("n", 0))
		var price := int(e.get("price", 0))
		var q := int(sell_qty.get(key, 0))
		_plabel("%s  (%d)" % [_bare(key), have], Vector2(16, y), Vector2(180, 22), 11, Color(0.95, 0.93, 0.86))
		_plabel(_fmt(price) + " XP", Vector2(196, y), Vector2(80, 22), 10, Color(1, 0.84, 0.45))
		var k2 := key
		_pbutton("-", Vector2(286, y - 4), Vector2(26, 24), func(): _sell_adj(k2, -1), 14)
		_plabel("×%d" % q, Vector2(318, y), Vector2(40, 22), 11, Color(1, 0.95, 0.7))
		_pbutton("+", Vector2(356, y - 4), Vector2(26, 24), func(): _sell_adj(k2, 1), 14)
		y += 30

	if pages > 1:
		_pbutton("◀", Vector2(16, 236), Vector2(28, 26), func(): sell_page -= 1; _render_panel(), 11)
		_plabel("%d/%d" % [sell_page + 1, pages], Vector2(48, 240), Vector2(50, 20), 10, Color(0.9, 0.88, 0.8))
		_pbutton("▶", Vector2(100, 236), Vector2(28, 26), func(): sell_page += 1; _render_panel(), 11)

	var can := total_n > 0
	_pbutton(("판매 %d개 · %s XP" % [total_n, _fmt(total_xp)]) if can else "수량을 선택하세요",
		Vector2(252, 232), Vector2(192, 32), func(): _do_sell(), 11)
	if boot.get("last_sale") != null:
		_pbutton("되돌리기", Vector2(160, 234), Vector2(86, 28), func(): _undo_sell(), 10)


func _sell_adj(key: String, d: int) -> void:
	var have := 0
	var lst: Array = []
	var lraw = boot.get("inventory_list", [])
	if typeof(lraw) == TYPE_ARRAY:
		lst = lraw
	for e in lst:
		if typeof(e) == TYPE_DICTIONARY and str(e.get("key", "")) == key:
			have = int(e.get("n", 0))
			break
	var cur := int(sell_qty.get(key, 0)) + d
	sell_qty[key] = maxi(0, mini(have, cur))
	_render_panel()


func _do_sell() -> void:
	var items := {}
	for k in sell_qty.keys():
		var n := int(sell_qty[k])
		if n > 0:
			items[str(k)] = n
	if items.is_empty():
		return
	_api("sell", {"items": items})
	sell_qty = {}


func _undo_sell() -> void:
	_api("sell/undo", {})


func _render_strengthen() -> void:
	var s: Dictionary = _dict_of(boot.get("strengthen"))
	var rod_band: Dictionary = _dict_of(s.get("rod_band"))
	var w_band: Dictionary = _dict_of(s.get("weapon_band"))
	_plabel(_bare(str(s.get("rod_name", "낚시대"))), Vector2(16, 74), Vector2(300, 22), 13, Color(0.95, 0.93, 0.86))
	_plabel("Lv.%d / 15" % int(s.get("rod_level", 0)), Vector2(320, 74), Vector2(110, 22), 12, Color(0.9, 0.9, 0.8))
	_plabel("성공 %s%%   파괴 %s%%   %s XP" % [str(rod_band.get("success", 100)), str(rod_band.get("destroy", 0)),
		_fmt(int(rod_band.get("cost", 0)))], Vector2(16, 96), Vector2(320, 20), 11, Color(1, 0.82, 0.5))
	_pbutton("강화", Vector2(360, 80), Vector2(76, 30), func(): _strengthen("rod"))

	_plabel("무기 (ATK)", Vector2(16, 152), Vector2(300, 22), 13, Color(0.95, 0.93, 0.86))
	_plabel("+%d / 15" % int(s.get("weapon_level", 0)), Vector2(320, 152), Vector2(110, 22), 12, Color(0.9, 0.9, 0.8))
	_plabel("성공 %s%%   파괴 %s%%   %s XP" % [str(w_band.get("success", 100)), str(w_band.get("destroy", 0)),
		_fmt(int(w_band.get("cost", 0)))], Vector2(16, 174), Vector2(320, 20), 11, Color(1, 0.82, 0.5))
	_pbutton("강화", Vector2(360, 158), Vector2(76, 30), func(): _strengthen("weapon"))
	_plabel("성공 +1 / 실패 −1 / 확률적 파괴(0) · 최대 +15", Vector2(16, 240), Vector2(420, 20), 11,
		Color(0.8, 0.78, 0.72))


func _render_cook() -> void:
	var ck := _dict_of(boot.get("cooking"))
	var cost := int(_or(ck.get("cost"), 1000))
	_plabel("재료 3개를 골라 조합 (비용 %s XP)" % _fmt(cost), Vector2(16, 38), Vector2(300, 20), 11,
		Color(0.9, 0.88, 0.8))
	for i in 3:
		var filled: String = str(cook_slots[i]) if i < cook_slots.size() else ""
		var label := _bare(filled) if filled != "" else "재료 선택"
		var idx := i
		_pbutton(label, Vector2(16 + i * 148, 62), Vector2(136, 38),
			func(): _cook_remove(idx), 11)

	var inv: Dictionary = _dict_of(_dict_of(boot.get("owned")).get("inventory"))
	var keys: Array = []
	for k in inv.keys():
		if int(inv[k]) > 0:
			keys.append(str(k))
	keys.sort_custom(func(a, b): return int(inv[a]) > int(inv[b]))
	var per := 6
	var pages: int = maxi(1, int(ceil(float(keys.size()) / float(per))))
	if cook_page >= pages:
		cook_page = pages - 1
	if cook_page < 0:
		cook_page = 0
	_plabel("가방 재료 (%d/%d)" % [cook_page + 1, pages], Vector2(16, 88), Vector2(200, 16), 10,
		Color(0.85, 0.83, 0.76))
	var y := 106
	for key in keys.slice(cook_page * per, cook_page * per + per):
		var cnt := int(inv[key])
		_plabel("%s ×%d" % [_bare(key), cnt], Vector2(16, y), Vector2(240, 18), 10, Color(0.94, 0.92, 0.86))
		var kk := str(key)
		_pbutton("넣기", Vector2(346, y - 4), Vector2(78, 20), func(): _cook_add(kk), 9)
		y += 24
	if pages > 1:
		_pbutton("◀", Vector2(352, 84), Vector2(26, 20), func(): cook_page -= 1; _render_panel(), 9)
		_pbutton("▶", Vector2(418, 84), Vector2(26, 20), func(): cook_page += 1; _render_panel(), 9)
	_pbutton("요리하기", Vector2(16, 258), Vector2(200, 30), func(): _cook(), 13)
	_pbutton("초기화", Vector2(228, 258), Vector2(90, 30), func(): cook_slots = []; _render_panel(), 11)


func _cook_remove(idx: int) -> void:
	if idx < cook_slots.size():
		cook_slots.remove_at(idx)
	_render_panel()


func _on_boat_area(p: Vector2i) -> bool:
	return absi(p.x - BOAT_AT.x) <= 1 and absi(p.y - BOAT_AT.y) <= 1


func _near_water(cell: Vector2i) -> bool:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if _in_pond(cell + d):
			return true
	return false


func _near_lava(cell: Vector2i) -> bool:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 0)]:
		if lava_cells.has(cell + d):
			return true
	return false


func _fish_location() -> String:
	# 물이 있는 곳이면 어디든 낚시 가능. 선착장 끝/배 = 깊은 물, 던전 용암 = 용암 낚시.
	var p := _player_cell()
	if scene_id == "dungeon" and _near_lava(p):
		return "volcano"
	if _on_boat_area(p):
		return "sea"
	if _in_pond(p) or _near_water(p):
		return "pond"
	return ""


func _fish_spot_name(loc: String) -> String:
	match loc:
		"sea":
			return "깊은 물 (배)"
		"volcano":
			return "용암"
		"pond":
			return "호수"
		_:
			return "물가 아님"


func _render_fish() -> void:
	var f: Dictionary = _dict_of(boot.get("fishing"))
	var stam: Dictionary = _dict_of(boot.get("stamina"))
	var st_cur := int(stam.get("cur", 0))
	var st_max := int(stam.get("max", 10))
	var loc := _fish_location()

	_plabel("낚시터: " + _fish_spot_name(loc), Vector2(16, 40), Vector2(220, 20), 12, Color(1, 0.9, 0.7))
	_plabel("ST %d/%d" % [st_cur, st_max], Vector2(250, 40), Vector2(80, 20), 11,
		Color(0.6, 0.9, 1.0) if st_cur > 0 else Color(1, 0.55, 0.5))
	if st_cur <= 0:
		_pbutton("ST 충전 %s XP" % _fmt(int(stam.get("refill_cost", 12000))),
			Vector2(330, 34), Vector2(120, 24), func(): _refill(), 9)
	_plabel("미끼: " + _bare(str(f.get("bait", "worm"))), Vector2(16, 64), Vector2(200, 20), 10,
		Color(0.88, 0.86, 0.8))

	if fish_state == "idle":
		if loc == "":
			_plabel("물가로 다가가세요 - 연못 · 선착장 · 용암", Vector2(16, 120), Vector2(430, 22), 11,
				Color(1, 0.85, 0.65))
			return
		_pbutton("낚싯대 던지기", Vector2(16, 108), Vector2(180, 38), func(): _fish_cast(), 14)
		_plabel("스타듀식: 바 위에서 물고기를 따라가며 게이지를 채우세요", Vector2(16, 160), Vector2(430, 36),
			10, Color(0.85, 0.85, 0.8))
	elif fish_state == "casting":
		_plabel("낚싯대를 던지는 중...", Vector2(16, 110), Vector2(300, 22), 13, Color(1, 0.9, 0.5))
	elif fish_state == "wait":
		_plabel("입질을 기다리는 중...", Vector2(16, 110), Vector2(300, 22), 13, Color(0.9, 0.95, 1.0))
	elif fish_state == "fight":
		_plabel("지금이다! 길게 눌러 물고기를 쫓아가세요", Vector2(16, 96), Vector2(430, 20), 11,
			Color(1, 0.92, 0.6))
		pass
	elif fish_state == "resolving":
		_plabel("결과 처리 중...", Vector2(16, 110), Vector2(200, 20), 12, Color(0.9, 0.9, 0.8))


func _render_fish_bar() -> void:
	fish_nodes.clear()
	var tx := 248.0
	var ty := 72.0
	var tw := 46.0
	var th := 186.0
	var track := ColorRect.new()
	track.color = Color(0.09, 0.10, 0.14, 0.95)
	track.position = Vector2(tx, ty)
	track.size = Vector2(tw, th)
	panel.add_child(track)

	var bar_h := th * fish_bar_pct
	var bar := ColorRect.new()
	bar.color = Color(0.42, 0.80, 0.45, 0.92)
	bar.size = Vector2(tw - 6, bar_h)
	bar.position = Vector2(tx + 3, ty + th * (1.0 - fish_py) - bar_h / 2)
	panel.add_child(bar)

	var icon := ColorRect.new()
	icon.color = Color(1.0, 0.62, 0.25)
	icon.size = Vector2(22, 14)
	icon.position = Vector2(tx + tw / 2 - 11, ty + th * (1.0 - fish_fy) - 7)
	panel.add_child(icon)

	var meter_bg := ColorRect.new()
	meter_bg.color = Color(0.09, 0.10, 0.14, 0.95)
	meter_bg.position = Vector2(tx + tw + 10, ty)
	meter_bg.size = Vector2(16, th)
	panel.add_child(meter_bg)

	var prog := ColorRect.new()
	prog.color = Color(0.35, 0.72, 0.95) if fish_progress > 0.33 else Color(0.95, 0.45, 0.35)
	prog.size = Vector2(12, th * clampf(fish_progress, 0.0, 1.0))
	prog.position = Vector2(tx + tw + 12, ty + th * (1.0 - clampf(fish_progress, 0.0, 1.0)))
	panel.add_child(prog)

	fish_nodes = {"bar": bar, "icon": icon, "prog": prog, "ty": ty, "th": th, "tx": tx, "tw": tw}

	_plabel("패턴: " + _pattern_ko(fish_pattern), Vector2(16, 250), Vector2(160, 20), 10,
		Color(0.8, 0.9, 1.0))


func _pattern_ko(p: String) -> String:
	match p:
		"smooth":
			return "규칙적"
		"darter":
			return "돌진형"
		"sinker":
			return "가라앉기"
		"floater":
			return "떠오르기"
		"spike":
			return "급변형"
		_:
			return "혼합"


func _buy(key: String) -> void:
	_api("shop/buy", {"item": key, "count": 1})


func _strengthen(kind: String) -> void:
	_api("strengthen/" + kind, {})


func _cook_add(key: String) -> void:
	if cook_slots.size() < 3:
		cook_slots.append(key)
	_render_panel()


func _cook() -> void:
	if cook_slots.size() < 3:
		_toast("재료 3개를 선택하세요")
		return
	_api("cooking", {"slots": cook_slots})
	cook_slots = []


func _render_plot() -> void:
	var p = _dict_of(boot.get("plot"))
	var slot := int(p.get("slot", -1))
	var built := bool(p.get("built", false))
	var quest := int(p.get("quest", 0))
	var kills := int(boot.get("dungeon_kills", 0))
	_plabel("영토와 집 - 목수", Vector2(16, 34), Vector2(300, 20), 12, Color(1, 0.9, 0.7))

	if slot < 0:
		_plabel("아직 영토가 없습니다 (4,000 XP)", Vector2(16, 64), Vector2(400, 20), 11, Color(0.92, 0.9, 0.84))
		_pbutton("영토 구매", Vector2(16, 92), Vector2(200, 36), func(): _plot_buy(), 13)
		return

	_plabel("내 영토 - 택지 %d" % (slot + 1), Vector2(16, 60), Vector2(300, 20), 12, Color(1, 0.92, 0.75))
	if built:
		_plabel("집이 완성되었습니다. 마을에서 확인해 보세요.", Vector2(16, 88), Vector2(430, 20), 11,
			Color(0.7, 0.95, 0.75))
		return

	# 건설 진행 중 — 즉시 완성 아님
	var prog := float(p.get("progress", 0.0))
	if not bool(p.get("building_started", false)) == false and prog < 1.0 or (p.has("building_started") and not built):
		var stage := "터파기"
		if prog >= 0.66:
			stage = "지붕"
		elif prog >= 0.33:
			stage = "골조"
		_plabel("건설 중 - " + stage, Vector2(16, 88), Vector2(300, 20), 12, Color(1, 0.9, 0.7))
		var bar_bg := ColorRect.new()
		bar_bg.color = Color(0.22, 0.16, 0.10)
		bar_bg.position = Vector2(16, 114)
		bar_bg.size = Vector2(420, 20)
		panel.add_child(bar_bg)
		var bar := ColorRect.new()
		bar.color = Color(0.55, 0.78, 0.45)
		bar.position = Vector2(18, 116)
		bar.size = Vector2(416 * clampf(prog, 0.0, 1.0), 16)
		panel.add_child(bar)
		_plabel("%d%%  (남은 시간 약 %d초)" % [int(prog * 100.0), int(p.get("remain", 0))],
			Vector2(16, 140), Vector2(420, 20), 11, Color(0.95, 0.92, 0.84))
		_plabel("목수가 일하는 중입니다. 시간이 지나면 완성됩니다.", Vector2(16, 166), Vector2(430, 20),
			10, Color(0.85, 0.82, 0.75))
		return

	if quest == 0:
		_plabel("목수: \"내 집을 짓고 싶다고? 먼저 실력을 보여주게.\"", Vector2(16, 92), Vector2(430, 20), 11,
			Color(0.9, 0.88, 0.8))
		_plabel("퀘스트 - 던전 몬스터 1마리 처치", Vector2(16, 118), Vector2(430, 20), 11, Color(1, 0.84, 0.45))
		_pbutton("퀘스트 받기", Vector2(16, 148), Vector2(200, 36), func(): _quest_start(), 13)
	elif quest == 1:
		_plabel("진행 중 - 던전 몬스터 처치", Vector2(16, 92), Vector2(430, 20), 11, Color(0.95, 0.9, 0.8))
		_plabel("처치 %d / 1" % kills, Vector2(16, 118), Vector2(300, 20), 12,
			Color(0.7, 0.95, 0.75) if kills >= 1 else Color(1, 0.8, 0.55))
		if kills >= 1:
			_pbutton("완료 보고", Vector2(16, 148), Vector2(200, 36), func(): _quest_claim(), 13)
	else:
		_plabel("퀘스트 완료! 이제 집을 지을 수 있습니다.", Vector2(16, 92), Vector2(430, 20), 11,
			Color(0.7, 0.95, 0.75))
		_plabel("건설 비용 - 3,000 XP", Vector2(16, 118), Vector2(300, 20), 11, Color(1, 0.84, 0.45))
		_pbutton("집 짓기", Vector2(16, 148), Vector2(200, 36), func(): _plot_build(), 13)


func _plot_call(path: String, ok_msg: String) -> void:
	_js_fetch(path, "POST", "{}", func(code: int, data: Dictionary):
		if code == 200 and data.get("ok", false):
			_toast(ok_msg)
			if path.find("build") >= 0:
				_build_scene()
		else:
			_toast("실패: " + str(data.get("error", code)))
		_fetch_boot()
		if panel_open:
			_render_panel())


func _plot_buy() -> void:
	_plot_call("/api/game/plot/buy", "영토를 구매했습니다!")


func _plot_build() -> void:
	_plot_call("/api/game/plot/build", "목수가 집을 지었습니다!")


func _quest_start() -> void:
	_plot_call("/api/game/plot/quest/start", "퀘스트를 받았습니다 - 던전 몬스터 1마리")


func _quest_claim() -> void:
	_plot_call("/api/game/plot/quest/claim", "퀘스트 완료! 이제 집을 지을 수 있습니다")


func _open_battle() -> void:
	dun_busy = false
	battle_open = true
	if bt_layer == null:
		_build_battle_overlay()
	bt_layer.visible = true
	_render_battle_overlay()


func _close_battle() -> void:
	battle_open = false
	if bt_layer != null:
		bt_layer.visible = false


func _bt_style(col: Color, border: Color, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	return sb


func _bt_label(parent: Node, text: String, pos: Vector2, size: Vector2, fs: int, col: Color,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	l.add_theme_font_override("font", ui_font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _bt_plate(parent: Node, pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.add_theme_stylebox_override("panel", _bt_style(Color(0.10, 0.09, 0.13, 0.92), Color(0.55, 0.50, 0.40), 8))
	parent.add_child(p)
	return p


func _bt_bar(parent: Node, pos: Vector2, size: Vector2, col: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08, 0.95)
	bg.position = pos
	bg.size = size
	parent.add_child(bg)
	var f := ColorRect.new()
	f.color = col
	f.position = pos + Vector2(2, 2)
	f.size = Vector2(size.x - 4, size.y - 4)
	parent.add_child(f)
	return f


func _bt_button(parent: Node, text: String, pos: Vector2, size: Vector2, fs: int,
		col: Color, border: Color, cb: Callable, key_hint: String = "") -> void:
	var b := Button.new()
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _bt_style(col, border, 7))
	var hv := _bt_style(col.lightened(0.12), border, 7)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", _bt_style(col.darkened(0.15), border, 7))
	b.add_theme_font_override("font", ui_font)
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", Color(0.06, 0.06, 0.08))
	b.pressed.connect(cb)
	parent.add_child(b)
	var lbl := _bt_label(parent, text, Vector2(0, 0), size, fs, Color(0.05, 0.05, 0.07), HORIZONTAL_ALIGNMENT_CENTER)
	lbl.position = pos + Vector2(0, (size.y - fs - 4) / 2.0)
	lbl.size = Vector2(size.x, fs + 6)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if key_hint != "":
		var kh := _bt_label(parent, key_hint, pos + Vector2(-22, (size.y - 12) / 2.0), Vector2(20, 14), 9,
			Color(1, 0.95, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)
		kh.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _bt_diamond(parent: Node, text: String, pos: Vector2, side: float, col: Color,
		border: Color, cb: Callable) -> void:
	var b := Button.new()
	b.position = pos
	b.size = Vector2(side, side)
	b.pivot_offset = Vector2(side / 2, side / 2)
	b.rotation = PI / 4.0
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _bt_style(col, border, 6))
	b.add_theme_stylebox_override("hover", _bt_style(col.lightened(0.12), border, 6))
	b.add_theme_stylebox_override("pressed", _bt_style(col.darkened(0.15), border, 6))
	b.pressed.connect(cb)
	parent.add_child(b)
	var lbl := _bt_label(parent, text, pos, Vector2(side, side), 10,
		Color(0.06, 0.06, 0.08), HORIZONTAL_ALIGNMENT_CENTER)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_battle_overlay() -> void:
	bt_layer = CanvasLayer.new()
	bt_layer.layer = 62
	add_child(bt_layer)

	var root := Control.new()
	root.size = Vector2(640, 360)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	bt_layer.add_child(root)

	# 하늘 / 땅 / 아레나
	var sky := ColorRect.new()
	sky.color = Color(0.42, 0.26, 0.20)
	sky.size = Vector2(640, 360)
	root.add_child(sky)
	var sky2 := ColorRect.new()
	sky2.color = Color(0.62, 0.34, 0.22)
	sky2.size = Vector2(640, 150)
	root.add_child(sky2)
	var ground := ColorRect.new()
	ground.color = Color(0.34, 0.30, 0.20)
	ground.position = Vector2(0, 150)
	ground.size = Vector2(640, 210)
	root.add_child(ground)
	var arena := Panel.new()
	arena.position = Vector2(90, 150)
	arena.size = Vector2(470, 190)
	arena.add_theme_stylebox_override("panel", _bt_style(Color(0.52, 0.43, 0.26), Color(0.62, 0.52, 0.32), 96))
	root.add_child(arena)
	var arena2 := Panel.new()
	arena2.position = Vector2(120, 168)
	arena2.size = Vector2(410, 160)
	arena2.add_theme_stylebox_override("panel", _bt_style(Color(0.62, 0.51, 0.31), Color(0.62, 0.51, 0.31), 90))
	root.add_child(arena2)

	# 몬스터 (오른쪽 위, 왼쪽을 봄)
	bt_enemy_tex = TextureRect.new()
	bt_enemy_tex.position = Vector2(392, 56)
	bt_enemy_tex.size = Vector2(150, 150)
	bt_enemy_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bt_enemy_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bt_enemy_tex.flip_h = true
	root.add_child(bt_enemy_tex)

	# 플레이어 (왼쪽 아래, 오른쪽을 봄)
	bt_player_tex = TextureRect.new()
	bt_player_tex.position = Vector2(48, 168)
	bt_player_tex.size = Vector2(168, 168)
	bt_player_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bt_player_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(bt_player_tex)

	# 참격 이펙트 (공격 시 표시)
	bt_slash = TextureRect.new()
	var sat := AtlasTexture.new()
	sat.atlas = tex_dungeon
	sat.region = Rect2((62 % 12) * SRC, (62 / 12) * SRC, SRC, SRC)
	bt_slash.texture = sat
	bt_slash.position = Vector2(360, 30)
	bt_slash.size = Vector2(210, 210)
	bt_slash.pivot_offset = Vector2(105, 105)
	bt_slash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bt_slash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bt_slash.modulate = Color(1, 1, 1, 1)
	bt_slash.visible = false
	bt_slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bt_slash)

	# ── 적 정보 (우상단) ──
	var ep := _bt_plate(root, Vector2(438, 14), Vector2(188, 54))
	bt_e_name = _bt_label(ep, "MONSTER", Vector2(10, 5), Vector2(120, 16), 11, Color(0.96, 0.94, 0.86))
	bt_e_lv = _bt_label(ep, "Lv 1", Vector2(140, 5), Vector2(40, 16), 10, Color(0.92, 0.90, 0.80), HORIZONTAL_ALIGNMENT_RIGHT)
	_bt_label(ep, "HP", Vector2(8, 23), Vector2(20, 12), 9, Color(0.85, 0.85, 0.78))
	bt_e_hp = _bt_bar(ep, Vector2(28, 24), Vector2(112, 9), Color(0.35, 0.78, 0.35))
	bt_e_hp_txt = _bt_label(ep, "", Vector2(142, 21), Vector2(44, 12), 9, Color(0.96, 0.94, 0.86))
	_bt_label(ep, "ST", Vector2(8, 38), Vector2(20, 12), 9, Color(0.85, 0.85, 0.78))
	bt_e_st = _bt_bar(ep, Vector2(28, 39), Vector2(112, 9), Color(0.95, 0.80, 0.25))
	bt_e_st_txt = _bt_label(ep, "", Vector2(142, 36), Vector2(44, 12), 9, Color(0.96, 0.94, 0.86))

	# ── 내 정보 (좌하단) ──
	var pp := _bt_plate(root, Vector2(16, 258), Vector2(212, 56))
	bt_p_name = _bt_label(pp, "ME", Vector2(10, 5), Vector2(130, 16), 11, Color(0.92, 0.90, 0.82))
	bt_p_lv = _bt_label(pp, "Lv 1", Vector2(150, 5), Vector2(52, 16), 10, Color(0.90, 0.88, 0.80), HORIZONTAL_ALIGNMENT_RIGHT)
	_bt_label(pp, "HP", Vector2(8, 24), Vector2(20, 12), 9, Color(0.85, 0.85, 0.78))
	bt_p_hp = _bt_bar(pp, Vector2(28, 25), Vector2(136, 9), Color(0.35, 0.78, 0.35))
	bt_p_hp_txt = _bt_label(pp, "", Vector2(166, 22), Vector2(44, 12), 9, Color(0.92, 0.90, 0.82))
	_bt_label(pp, "ST", Vector2(8, 39), Vector2(20, 12), 9, Color(0.85, 0.85, 0.78))
	bt_p_st = _bt_bar(pp, Vector2(28, 40), Vector2(136, 9), Color(0.95, 0.80, 0.25))
	bt_p_st_txt = _bt_label(pp, "", Vector2(166, 37), Vector2(44, 12), 9, Color(0.92, 0.90, 0.82))

	# ── 버튼 (우하단 3개 + 가운데 공격) ──
	# 다이아몬드 배열 — 위:공격, 왼쪽:아이템, 오른쪽:방어, 아래:도망
	var dc := Vector2(516, 250)      # 다이아몬드 중심
	var dr := 42.0                   # 반지름
	var ds := 46.0                   # 버튼 한 변
	_bt_diamond(root, "공격", dc + Vector2(-ds / 2, -dr - ds / 2), ds,
		Color(0.97, 0.96, 0.92), Color(0.42, 0.36, 0.24),
		func():
			_play_attack_fx()
			_dungeon_turn("attack"))
	_bt_diamond(root, "아이템", dc + Vector2(-dr - ds / 2, -ds / 2), ds,
		Color(0.94, 0.91, 0.78), Color(0.45, 0.40, 0.26),
		func(): _dungeon_turn("heal"))
	_bt_diamond(root, "방어", dc + Vector2(dr - ds / 2, -ds / 2), ds,
		Color(0.82, 0.89, 0.97), Color(0.30, 0.42, 0.55),
		func(): _dungeon_turn("defense"))
	_bt_diamond(root, "도망", dc + Vector2(-ds / 2, dr - ds / 2), ds,
		Color(0.97, 0.84, 0.82), Color(0.55, 0.32, 0.30),
		func(): _dungeon_turn("evade"))

	# ── 하단 배너 ──
	var bar := ColorRect.new()
	bar.color = Color(0.04, 0.03, 0.05)
	bar.position = Vector2(0, 330)
	bar.size = Vector2(640, 30)
	root.add_child(bar)
	bt_banner = _bt_label(root, "", Vector2(10, 335), Vector2(620, 20), 12, Color(0.98, 0.85, 0.25))


func _play_attack_fx() -> void:
	if bt_slash == null:
		return
	bt_slash.visible = true
	bt_slash.modulate = Color(1, 1, 1, 1)
	bt_slash.scale = Vector2(0.6, 0.6)
	bt_slash.rotation = -0.45
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(bt_slash, "scale", Vector2(1.35, 1.35), 0.20).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(bt_slash, "rotation", 0.30, 0.20)
	tw.tween_property(bt_slash, "modulate:a", 0.0, 0.34).set_delay(0.14)
	tw.chain().tween_callback(func(): bt_slash.visible = false)
	# 몬스터 흰색 플래시
	if bt_enemy_tex != null:
		var ft := create_tween()
		ft.tween_property(bt_enemy_tex, "modulate", Color(4, 4, 4, 1), 0.05)
		ft.tween_property(bt_enemy_tex, "modulate", Color(1, 1, 1, 1), 0.20)


func _render_battle_overlay() -> void:
	if bt_layer == null or dun_state.is_empty():
		return
	var mname := _bare(str(dun_state.get("monster_name", "몬스터")))
	var mhp := int(dun_state.get("monster_hp", 0))
	var mmax := maxi(1, int(dun_state.get("monster_max_hp", 1)))
	var matk := int(dun_state.get("monster_atk", 0))
	var php := int(dun_state.get("player_hp", 0))
	var pmax := maxi(1, int(dun_state.get("player_max_hp", 1)))
	var st := _dict_of(boot.get("stamina"))
	var st_cur := int(st.get("cur", 0))
	var st_max := maxi(1, int(st.get("max", 10)))
	var lv := int(boot.get("level", 1))

	bt_e_name.text = mname
	bt_e_lv.text = "Lv %d" % mini(99, 1 + dun_floor)
	bt_e_hp.size.x = maxf(2.0, 108.0 * clampf(float(mhp) / float(mmax), 0.0, 1.0))
	bt_e_hp_txt.text = "%d/%d" % [mhp, mmax]
	bt_e_st.size.x = maxf(2.0, 108.0 * clampf(float(matk) / 50.0, 0.05, 1.0))
	bt_e_st_txt.text = "%d" % matk

	bt_p_name.text = "나"
	bt_p_lv.text = "Lv %d" % lv
	bt_p_hp.size.x = maxf(2.0, 132.0 * clampf(float(php) / float(pmax), 0.0, 1.0))
	bt_p_hp_txt.text = "%d/%d" % [php, pmax]
	bt_p_st.size.x = maxf(2.0, 132.0 * clampf(float(st_cur) / float(st_max), 0.0, 1.0))
	bt_p_st_txt.text = "%d/%d" % [st_cur, st_max]

	# 스프라이트
	if dun_target >= 0 and dun_target < monsters.size():
		var sn: Sprite2D = monsters[dun_target]["node"]
		if sn != null and sn.texture != null:
			var at := AtlasTexture.new()
			at.atlas = sn.texture
			at.region = sn.region_rect
			bt_enemy_tex.texture = at
	bt_player_tex.texture = player_sprite.texture
	if player_sprite.texture != null and player_sprite.region_enabled:
		var pat := AtlasTexture.new()
		pat.atlas = player_sprite.texture
		pat.region = player_sprite.region_rect
		bt_player_tex.texture = pat
	bt_player_tex.modulate = player_sprite.modulate

	var last := ""
	if not dun_logs.is_empty():
		last = str(dun_logs[dun_logs.size() - 1])
	if bool(dun_state.get("ended", false)):
		bt_banner.text = last
	else:
		bt_banner.text = last if last != "" else "야생의 %s 이(가) 나타났다!" % mname


func _dungeon_enter() -> void:
	var gid := str(boot.get("guild_id", ""))
	dun_busy = true
	dun_logs = []
	# 가장 가까운 살아있는 몬스터를 대상으로
	dun_target = -1
	var best := 1e9
	for i in monsters.size():
		if not monsters[i]["alive"]:
			continue
		var d: float = player.position.distance_to(monsters[i]["pos"])
		if d < best:
			best = d
			dun_target = i
	_toast("던전에 입장하는 중...")
	_js_fetch("/dashboard/%s/api/minigame/dungeon/enter" % gid, "POST",
		JSON.stringify({"dungeon_id": "1"}), _on_dungeon_enter)


func _on_dungeon_enter(code: int, data: Dictionary) -> void:
	dun_busy = false
	if code != 200 or not data.get("ok", false):
		_toast("입장 실패: " + str(data.get("error", code)))
		return
	dun_state = _dict_of(data.get("session"))
	if dun_state.is_empty():
		_toast("전투 정보를 받지 못했습니다")
		return
	dun_state["ended"] = false
	dun_logs = ["야생의 %s 등장!" % _clean(str(dun_state.get("monster_name", "몬스터")))]
	_open_battle()


func _dungeon_turn(action: String) -> void:
	if dun_busy or bool(dun_state.get("ended", false)):
		return
	dun_busy = true
	var gid := str(boot.get("guild_id", ""))
	_js_fetch("/dashboard/%s/api/minigame/dungeon/turn" % gid, "POST",
		JSON.stringify({"action": action}), _on_dungeon_turn)


func _on_dungeon_turn(code: int, data: Dictionary) -> void:
	dun_busy = false
	if code != 200 or not data.get("ok", false):
		_toast("전투 실패: " + str(data.get("error", code)))
		return
	for line in _arr_of(data.get("logs")):
		dun_logs.append(_clean(str(line)))
	dun_state["player_hp"] = int(data.get("player_hp", dun_state.get("player_hp", 0)))
	dun_state["monster_hp"] = int(data.get("monster_hp", dun_state.get("monster_hp", 0)))
	if data.get("ended", false):
		var win := str(data.get("result", "")) == "win"
		dun_state["ended"] = true
		if win:
			_kill_target_monster(_arr_of(data.get("drops")))
			dun_logs.append("🏆 승리! +%s XP" % _fmt(int(data.get("xp_gain", 0))))
			var drops: Array = _arr_of(data.get("drops"))
			if not drops.is_empty():
				var names: Array = []
				for d in drops:
					names.append(_bare(str(d)))
				dun_logs.append("🎁 획득: " + ", ".join(names))
		else:
			dun_logs.append("💀 패배… 마을로 돌아가 HP를 회복하세요")
		_fetch_boot()
	if battle_open:
		_render_battle_overlay()
		if bool(dun_state.get("ended", false)):
			var tw := create_tween()
			tw.tween_interval(1.8)
			tw.tween_callback(func(): _close_battle())
	if panel_open:
		_render_panel()


func _bar(pos: Vector2, size: Vector2, ratio: float, col: Color) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.09, 0.12)
	bg.position = pos
	bg.size = size
	panel.add_child(bg)
	var f := ColorRect.new()
	f.color = col
	f.position = pos + Vector2(1, 1)
	f.size = Vector2(maxf(0.0, (size.x - 2) * clampf(ratio, 0.0, 1.0)), size.y - 2)
	panel.add_child(f)


func _render_battle() -> void:
	if dun_state.is_empty():
		_plabel("전투 정보가 없습니다", Vector2(16, 90), Vector2(300, 24), 13, Color(1, 0.8, 0.6))
		return
	var mname := _clean(str(dun_state.get("monster_name", "몬스터")))
	var mhp := int(dun_state.get("monster_hp", 0))
	var mmax := maxi(1, int(dun_state.get("monster_max_hp", 1)))
	var php := int(dun_state.get("player_hp", 0))
	var pmax := maxi(1, int(dun_state.get("player_max_hp", 1)))
	var ended := bool(dun_state.get("ended", false))

	_plabel("야생의 " + mname if not ended else mname, Vector2(16, 40), Vector2(300, 22), 13,
		Color(1, 0.85, 0.85))
	_plabel("HP %d/%d" % [mhp, mmax], Vector2(330, 40), Vector2(110, 22), 11, Color(0.95, 0.85, 0.85))
	_bar(Vector2(16, 64), Vector2(424, 16), float(mhp) / float(mmax), Color(0.82, 0.28, 0.28))

	_plabel("나", Vector2(16, 88), Vector2(60, 20), 12, Color(0.85, 0.95, 1.0))
	_plabel("HP %d/%d" % [php, pmax], Vector2(330, 88), Vector2(110, 20), 11, Color(0.85, 0.95, 1.0))
	_bar(Vector2(16, 110), Vector2(424, 16), float(php) / float(pmax), Color(0.35, 0.75, 0.45))

	var y := 138
	var shown := dun_logs.slice(maxi(0, dun_logs.size() - 4))
	for line in shown:
		_plabel(str(line), Vector2(16, y), Vector2(430, 20), 9, Color(0.93, 0.9, 0.82))
		y += 22

	if ended:
		_pbutton("닫기", Vector2(16, 250), Vector2(200, 34), func(): _close_panel(); _toast("마을에서 회복하세요"), 13)
		_pbutton("다시 입장", Vector2(228, 250), Vector2(200, 34), func(): _dungeon_enter(), 13)
		return

	var acts := [["attack", "공격"], ["defense", "방어"], ["heal", "회복"], ["evade", "회피"]]
	for i in acts.size():
		var a: String = acts[i][0]
		var b := _pbutton(acts[i][1], Vector2(16 + i * 108, 250), Vector2(100, 34),
			func(): _dungeon_turn(a), 12)
		b.disabled = dun_busy


func _refill() -> void:
	var gid := str(boot.get("guild_id", ""))
	_js_fetch("/dashboard/%s/api/minigame/stamina/refill" % gid, "POST", "{}",
		func(code: int, data: Dictionary):
			if code == 200 and data.get("ok", false):
				_toast("ST 충전 → %d" % int(_dict_of(data.get("state")).get("st", 0)))
			else:
				_toast("충전 실패: " + str(data.get("error", code)))
			_fetch_boot()
			if panel_open:
				_render_panel())


func _build_fish_ui() -> void:
	fish_ui = Node2D.new()
	fish_ui.z_index = 60
	fish_ui.visible = false
	add_child(fish_ui)

	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.13, 0.10, 0.92)
	bg.size = Vector2(30, 132)
	bg.position = Vector2(-30, -66)
	fish_ui.add_child(bg)

	var track := ColorRect.new()
	track.color = Color(0.10, 0.11, 0.16)
	track.size = Vector2(22, 120)
	track.position = Vector2(-26, -60)
	fish_ui.add_child(track)

	var bar := ColorRect.new()
	bar.color = Color(0.46, 0.82, 0.42)
	bar.size = Vector2(22, 34)
	bar.position = Vector2(-26, -34)
	fish_ui.add_child(bar)

	var icon := ColorRect.new()
	icon.color = Color(0.35, 0.78, 0.98)
	icon.size = Vector2(11, 7)
	icon.position = Vector2(-21, -37)
	fish_ui.add_child(icon)

	var meter_bg := ColorRect.new()
	meter_bg.color = Color(0.10, 0.11, 0.16)
	meter_bg.size = Vector2(5, 120)
	meter_bg.position = Vector2(0, -60)
	fish_ui.add_child(meter_bg)

	var meter := ColorRect.new()
	meter.color = Color(0.95, 0.75, 0.25)
	meter.size = Vector2(5, 54)
	meter.position = Vector2(0, -28)
	fish_ui.add_child(meter)

	fish_ui_nodes = {"bar": bar, "icon": icon, "meter": meter, "track_h": 120.0, "track_y": -60.0}

	# 찌 (별도 노드 — 월드 좌표)
	bobber = ColorRect.new()
	bobber.color = Color(0.95, 0.35, 0.30)
	bobber.size = Vector2(9, 9)
	bobber.z_index = 56
	bobber.visible = false
	add_child(bobber)

	# 낚싯줄 — 얇은 세로 사각형 두 개로 근사 (Line2D 는 웹에서 불안정)
	fish_line = null


func _fish_cast() -> void:
	var loc := _fish_location()
	if loc == "":
		_toast("물가에서만 낚시할 수 있습니다")
		return
	fish_state = "casting"
	cast_t = 0.0
	fish_spot = loc
	fish_ui.visible = false
	bobber.visible = true
	if panel_open:
		_render_panel()
	var gid := str(boot.get("guild_id", ""))
	_js_fetch("/dashboard/%s/api/minigame/fishing/cast" % gid, "POST",
		JSON.stringify({"location": loc, "bait": str(_dict_of(boot.get("fishing")).get("bait", "worm"))}),
		_on_cast_data)


func _on_cast_data(code: int, data: Dictionary) -> void:
	if code != 200 or not data.get("ok", false):
		fish_state = "idle"
		_toast("낚시 실패: " + str(data.get("error", code)))
		_render_panel()
		return
	fish_token = str(data.get("token", ""))
	var f: Dictionary = _dict_of(data.get("fish"))
	fish_fid = str(f.get("id", ""))
	var mg: Dictionary = _dict_of(data.get("minigame"))
	fish_pattern = str(mg.get("pattern", "smooth"))
	fish_bar_pct = clampf(float(mg.get("bar", 0.28)), 0.12, 0.42)
	fish_speed_mult = clampf(float(mg.get("speed", 1.0)), 0.6, 2.0)
	fish_py = 0.5
	fish_fy = 0.5
	fish_progress = 0.62
	fish_t = 0.0
	fish_target = 0.5
	fish_next_jump = 0.0
	_toast("입질! " + _clean(str(f.get("name", ""))) + " - 길게 눌러 잡으세요")
	fish_state = "wait"
	fish_wait = 0.85
	_render_panel()


func _fish_tick(delta: float) -> void:
	# 던지기 모션
	if bobber != null:
		if fish_state == "casting":
			cast_t += delta
			var t := clampf(cast_t / 0.55, 0.0, 1.0)
			var from := player.position + Vector2(0, -40)
			var to := player.position + facing_dir() * 96.0 + Vector2(0, 10)
			bobber.position = from.lerp(to, t) + Vector2(0, -54.0 * sin(t * PI)) + Vector2(-5, -5)
			bobber.visible = true
		elif fish_state == "wait" or fish_state == "fight":
			bobber.visible = true
		else:
			bobber.visible = false

	if fish_state == "casting" and cast_t >= 0.55:
		fish_state = "wait"

	if fish_state == "wait":
		fish_wait -= delta
		if fish_wait <= 0.0:
			fish_state = "fight"
			if fish_ui != null:
				fish_ui.visible = true
			if panel_open:
				_render_panel()

	if fish_state != "fight":
		return

	fish_t += delta
	fish_hold = Input.is_key_pressed(KEY_SPACE) or fish_touch_hold
	# 플레이어 바
	var vy: float = 1.15 if fish_hold else -0.95
	fish_py = clampf(fish_py + vy * delta * fish_speed_mult, 0.0, 1.0)
	# 물고기 패턴
	var sp := fish_speed_mult
	match fish_pattern:
		"smooth":
			fish_fy = 0.5 + 0.34 * sin(fish_t * 1.7 * sp)
		"darter":
			fish_next_jump -= delta
			if fish_next_jump <= 0.0:
				fish_next_jump = randf_range(0.35, 0.8) / sp
				fish_target = clampf(fish_fy + randf_range(-0.55, 0.55), 0.02, 0.98)
			fish_fy = move_toward(fish_fy, fish_target, delta * 2.4 * sp)
		"sinker":
			fish_fy = 0.72 + 0.22 * sin(fish_t * 1.2 * sp)
			if randf() < 0.02 * sp:
				fish_fy = 0.1
		"floater":
			fish_fy = 0.24 + 0.20 * sin(fish_t * 1.5 * sp)
			if randf() < 0.02 * sp:
				fish_fy = 0.9
		"spike":
			fish_fy = 0.5 + 0.42 * sin(fish_t * 2.8 * sp) * cos(fish_t * 1.1)
		_:
			var phase := fmod(fish_t, 4.0)
			if phase < 1.4:
				fish_fy = 0.5 + 0.34 * sin(fish_t * 1.7 * sp)
			elif phase < 2.6:
				fish_next_jump -= delta
				if fish_next_jump <= 0.0:
					fish_next_jump = 0.4
					fish_target = clampf(fish_fy + randf_range(-0.6, 0.6), 0.02, 0.98)
				fish_fy = move_toward(fish_fy, fish_target, delta * 2.6 * sp)
			else:
				fish_fy = 0.72 + 0.2 * sin(fish_t * 3.4 * sp)
	fish_fy = clampf(fish_fy, 0.0, 1.0)

	# 게이지
	if absf(fish_fy - fish_py) <= fish_bar_pct * 0.5:
		fish_progress = minf(1.0, fish_progress + delta * 0.55)
	else:
		fish_progress = maxf(0.0, fish_progress - delta * 0.30)

	# 월드 UI 갱신 (플레이어 옆 세로 게이지)
	if fish_ui_nodes.has("bar"):
		var th: float = fish_ui_nodes["track_h"]
		var ty: float = fish_ui_nodes["track_y"]
		var bar: ColorRect = fish_ui_nodes["bar"]
		var bar_h := th * fish_bar_pct
		bar.size.y = bar_h
		bar.position.y = ty + th * (1.0 - fish_py) - bar_h / 2
		var icon: ColorRect = fish_ui_nodes["icon"]
		icon.position.y = ty + th * (1.0 - fish_fy) - 4
		var meter: ColorRect = fish_ui_nodes["meter"]
		var pr := clampf(fish_progress, 0.0, 1.0)
		meter.size.y = th * pr
		meter.position.y = ty + th * (1.0 - pr)
		meter.color = Color(0.95, 0.75, 0.25) if pr > 0.33 else Color(0.95, 0.4, 0.3)

	# 플레이어 옆에 게이지, 줄은 플레이어→찌
	if fish_ui != null and fish_ui.visible:
		fish_ui.position = player.position + Vector2(-50, -30)
	pass

	if fish_progress >= 1.0:
		_fish_finish(true)
	elif fish_progress <= 0.0:
		_fish_finish(false)


func _fish_finish(ok: bool) -> void:
	if fish_state == "resolving":
		return
	fish_state = "resolving"
	if bobber != null:
		bobber.visible = false
	pass
	if fish_ui != null:
		fish_ui.visible = false
	var gid := str(boot.get("guild_id", ""))
	_js_fetch("/dashboard/%s/api/minigame/fishing/resolve" % gid, "POST",
		JSON.stringify({"token": fish_token, "fid": fish_fid, "success": ok}),
		func(code: int, data: Dictionary):
			if code == 200 and data.get("ok", false):
				if data.get("success", false):
					_toast("잡았다! " + _clean(str(data.get("name", ""))))
				else:
					_toast("놓쳤다...")
			else:
				_toast("판정 실패: " + str(data.get("error", code)))
			fish_state = "idle"
			_fetch_boot()
			if panel_open:
				_render_panel())


func facing_dir() -> Vector2:
	match facing:
		"left":
			return Vector2(-1, 0)
		"right":
			return Vector2(1, 0)
		"up":
			return Vector2(0, -1)
		_:
			return Vector2(0, 1)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	# 좌상단 3개 막대 (XP / HP / ST)
	hud_bars.clear()
	for i in 3:
		var row := Control.new()
		row.position = Vector2(10, 8 + i * 22)
		row.size = Vector2(190, 18)
		layer.add_child(row)
		var tag := Label.new()
		tag.text = ["XP", "HP", "ST"][i]
		tag.position = Vector2(0, 1)
		tag.size = Vector2(24, 14)
		tag.add_theme_font_override("font", ui_font)
		tag.add_theme_font_size_override("font_size", 9)
		tag.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
		tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		tag.add_theme_constant_override("outline_size", 3)
		row.add_child(tag)
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.55)
		bg.position = Vector2(24, 3)
		bg.size = Vector2(150, 12)
		row.add_child(bg)
		var fill := ColorRect.new()
		fill.color = [Color(0.95, 0.82, 0.35), Color(0.85, 0.35, 0.35), Color(0.40, 0.70, 0.95)][i]
		fill.position = Vector2(25, 4)
		fill.size = Vector2(0, 10)
		row.add_child(fill)
		var val := Label.new()
		val.position = Vector2(178, 0)
		val.size = Vector2(90, 14)
		val.add_theme_font_override("font", ui_font)
		val.add_theme_font_size_override("font_size", 9)
		val.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
		val.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		val.add_theme_constant_override("outline_size", 3)
		row.add_child(val)
		hud_bars.append({"fill": fill, "val": val})

	hud_label = _ltr(Label.new())
	hud_label.position = Vector2(10, 74)
	hud_label.add_theme_font_override("font", ui_font)
	hud_label.add_theme_font_size_override("font_size", 14)
	hud_label.add_theme_color_override("font_color", Color(1, 0.96, 0.85))
	hud_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hud_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(hud_label)

	hint_label = _ltr(Label.new())
	hint_label.position = Vector2(10, 96)
	hint_label.add_theme_font_override("font", ui_font)
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(1, 1, 0.9, 0.78))
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint_label.add_theme_constant_override("outline_size", 4)
	hint_label.text = "WASD 이동 · E/SPACE 상호작용"
	layer.add_child(hint_label)

	toast_label = _ltr(Label.new())
	toast_label.position = Vector2(10, 116)
	toast_label.add_theme_font_override("font", ui_font)
	toast_label.add_theme_font_size_override("font_size", 14)
	toast_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	toast_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(toast_label)
	_update_hud()


func _update_hud() -> void:
	var count := others.size() + 1
	var net := "연결 중"
	if net_state == WebSocketPeer.STATE_OPEN:
		net = "온라인"
	elif net_state == WebSocketPeer.STATE_CLOSED:
		net = "오프라인"
	var where := "마을"
	match scene_id:
		"dungeon":
			where = "던전 B%dF" % dun_floor
		"town":
			where = "마을"
		_:
			where = _bare(str(_npc_info(scene_id)[2])) + "의 집"
	hud_label.text = "Lv.%d   %s   %s   접속 %d/10   %s" % [_player_level(), where, _clock_text(), count, net]
	_update_bars()


func _player_level() -> int:
	return maxi(1, int(boot.get("level", 1)))


func _update_bars() -> void:
	if hud_bars.size() < 3:
		return
	var xp := int(boot.get("xp", 0))
	var hp := _dict_of(boot.get("hp"))
	var st := _dict_of(boot.get("stamina"))
	var hp_cur := int(hp.get("cur", 1))
	var hp_max := maxi(1, int(hp.get("max", 1)))
	var st_cur := int(st.get("cur", 0))
	var st_max := maxi(1, int(st.get("max", 10)))
	# XP 는 5만 단위로 환산해 막대로 (표시는 실제 값)
	var xp_ratio := clampf(float(xp % 50000) / 50000.0, 0.0, 1.0)
	_set_bar(0, xp_ratio, _fmt(xp))
	_set_bar(1, float(hp_cur) / float(hp_max), "%d/%d" % [hp_cur, hp_max])
	_set_bar(2, float(st_cur) / float(st_max), "%d/%d" % [st_cur, st_max])


func _set_bar(i: int, ratio: float, text: String) -> void:
	if i >= hud_bars.size():
		return
	var fill: ColorRect = hud_bars[i]["fill"]
	fill.size.x = 148.0 * clampf(ratio, 0.0, 1.0)
	var val: Label = hud_bars[i]["val"]
	val.text = text


func _toast(msg: String) -> void:
	toast_label.text = msg
	toast_t = 2.4


func _clean(s) -> String:
	# 문자열 어디에 있든 이모지/기호를 제거 (폰트에 없어 토푸로 보이는 문제)
	var t := str(s)
	var out := ""
	for i in t.length():
		var ch := t.unicode_at(i)
		if (ch >= 0xAC00 and ch <= 0xD7A3) or (ch >= 0x20 and ch <= 0x7E) 			or ch == 0x3131 or ch == 0x3134 or ch == 0x314F:
			out += String.chr(ch)
	return out.strip_edges()


func _bare(s) -> String:
	# 앞쪽 이모지/기호 제거: 첫 한글·영문·숫자 문자부터 표시
	var t := str(s).strip_edges()
	var i := 0
	while i < t.length():
		var ch := t.unicode_at(i)
		var keep := (ch >= 0xAC00 and ch <= 0xD7A3) or (ch >= 0x41 and ch <= 0x7A) 			or (ch >= 0x30 and ch <= 0x39) or ch == 0x28
		if keep:
			break
		i += 1
	return t.substr(i).strip_edges()


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


# ──────────────────────────────────────────── 모바일 터치
var ltr_t := 0.0
const LTR_MARK := "\u200e"


func _ltr_fix(delta: float) -> void:
	ltr_t -= delta
	if ltr_t > 0.0:
		return
	ltr_t = 0.35
	_ltr_walk(self)


func _ltr_walk(n: Node) -> void:
	if n is Label:
		var l := n as Label
		if l.text != "" and not l.text.begins_with(LTR_MARK):
			l.text = LTR_MARK + l.text
	elif n is Button:
		var b := n as Button
		if b.text != "" and not b.text.begins_with(LTR_MARK):
			b.text = LTR_MARK + b.text
	for c in n.get_children():
		_ltr_walk(c)


func _xy_button(parent: Node, text: String, center: Vector2, col: Color, cb: Callable) -> void:
	var d := 30.0
	var b := Button.new()
	b.position = center - Vector2(d / 2, d / 2)
	b.size = Vector2(d, d)
	b.focus_mode = Control.FOCUS_NONE
	b.modulate.a = 0.82
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.30)
	sb.border_color = Color(1, 1, 1, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(15)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("pressed", _bt_style(col, Color(1, 1, 1, 0.9), 15))
	b.pressed.connect(cb)
	parent.add_child(b)
	var l := Label.new()
	l.text = text
	l.position = center - Vector2(d / 2, d / 2 - 3)
	l.size = Vector2(d, d)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", ui_font)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", col.lightened(0.25))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)


func _fish_try() -> void:
	if _fish_location() == "":
		return
	if int(_dict_of(boot.get("stamina")).get("cur", 0)) <= 0:
		_open_panel("fish")
	else:
		_fish_cast()


func _want_touch() -> bool:
	var sz := DisplayServer.window_get_size()
	# 데스크톱(넓은 화면 + 터치 없음)에서는 가상 버튼을 띄우지 않는다
	if sz.x > 1000 and not DisplayServer.is_touchscreen_available():
		return false
	if sz.y > sz.x:
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.has_feature("web"):
		# 가로로 강제 회전된 뒤에는 창이 가로라 위 조건에 안 걸린다 → 터치 지원 여부로 판단
		var mt := str(JavaScriptBridge.eval("(navigator.maxTouchPoints||0) > 0", true))
		if mt == "true":
			return true
		var q: String = str(JavaScriptBridge.eval("location.search", true))
		if q.find("touch=1") >= 0:
			return true
	return false


var joy_base: Control
var joy_knob: Panel
var joy_r := 62.0
var joy_id := -1


func _maybe_choose_look() -> void:
	var saved := ""
	if OS.has_feature("web"):
		saved = str(JavaScriptBridge.eval("localStorage.getItem('hana_look') || ''", true))
	if saved != "":
		_apply_look(saved)
		return
	_show_look_picker()


func _apply_look(code: String) -> void:
	var parts := code.split(":")
	if parts.size() < 2:
		return
	var tex := tex_farm if parts[0] == "farm" else tex_dungeon
	var idx := int(parts[1])
	player_sprite.texture = tex
	player_sprite.region_enabled = true
	player_sprite.region_rect = Rect2((idx % 12) * SRC, (idx / 12) * SRC, SRC, SRC)
	if parts.size() >= 3:
		var c := str(parts[2])
		var nums := c.replace("(", "").replace(")", "").split(",")
		if nums.size() >= 3:
			player_sprite.modulate = Color(float(nums[0]), float(nums[1]), float(nums[2]), 1.0)
	look_code = code


func _show_look_picker() -> void:
	look_layer = CanvasLayer.new()
	look_layer.layer = 70
	add_child(look_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	look_layer.add_child(dim)

	var box := Panel.new()
	box.position = Vector2(50, 16)
	box.size = Vector2(540, 328)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.92, 0.80)
	sb.border_color = Color(0.52, 0.34, 0.16)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	box.add_theme_stylebox_override("panel", sb)
	look_layer.add_child(box)

	var t := Label.new()
	t.text = "모험가를 선택하세요"
	t.position = Vector2(0, 10)
	t.size = Vector2(540, 26)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", ui_font)
	t.add_theme_font_size_override("font_size", 17)
	t.add_theme_color_override("font_color", Color(0.36, 0.20, 0.06))
	box.add_child(t)

	for i in LOOKS.size():
		var look: Dictionary = LOOKS[i]
		var code := "%s:%d:%s" % [str(look["tex"]), int(look["idx"]), str(look["tint"])]
		var tex := tex_farm if str(look["tex"]) == "farm" else tex_dungeon
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2((int(look["idx"]) % 12) * SRC, (int(look["idx"]) / 12) * SRC, SRC, SRC)
		var col := i % 4
		var row := i / 4

		var card := Button.new()
		card.position = Vector2(20 + col * 128, 44 + row * 92)
		card.size = Vector2(118, 84)
		card.focus_mode = Control.FOCUS_NONE
		var cb := StyleBoxFlat.new()
		cb.bg_color = Color(0.88, 0.80, 0.62)
		cb.border_color = Color(0.45, 0.30, 0.14)
		cb.set_border_width_all(3)
		cb.set_corner_radius_all(8)
		card.add_theme_stylebox_override("normal", cb)
		var hb: StyleBoxFlat = cb.duplicate()
		hb.bg_color = Color(1, 0.94, 0.74)
		card.add_theme_stylebox_override("hover", hb)
		card.pressed.connect(func():
			_apply_look(code)
			if OS.has_feature("web"):
				JavaScriptBridge.eval("localStorage.setItem('hana_look','%s')" % code, true)
			look_layer.queue_free())
		box.add_child(card)

		var img := TextureRect.new()
		img.texture = at
		img.position = Vector2(10, 10)
		img.size = Vector2(42, 42)
		img.modulate = look["tint"]
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(img)

		var nm := Label.new()
		nm.text = str(look["name"])
		nm.position = Vector2(54, 26)
		nm.size = Vector2(62, 34)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_override("font", ui_font)
		nm.add_theme_font_size_override("font_size", 13)
		nm.add_theme_color_override("font_color", Color(0.28, 0.16, 0.05))
		card.add_child(nm)

	var hint := Label.new()
	hint.text = "한 번 정하면 이 브라우저에서는 다시 묻지 않습니다"
	hint.position = Vector2(0, 300)
	hint.size = Vector2(540, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", ui_font)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.45, 0.32, 0.18))
	box.add_child(hint)


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.visible = false
	layer.add_child(fade_rect)


func _fade_to(cb: Callable) -> void:
	if fade_busy:
		cb.call()
		return
	fade_busy = true
	fade_rect.visible = true
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.16)
	tw.tween_callback(cb)
	tw.tween_property(fade_rect, "color:a", 0.0, 0.20)
	tw.tween_callback(func():
		fade_rect.visible = false
		fade_busy = false)


var mm_scale := 0.1
var mm_off := Vector2.ZERO


func _build_minimap() -> void:
	mm_layer = CanvasLayer.new()
	mm_layer.layer = 45
	add_child(mm_layer)

	var panel := Panel.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -150
	panel.offset_right = -10
	panel.offset_top = 10
	panel.offset_bottom = 150
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.10, 0.15, 0.88)
	sb.border_color = Color(0.80, 0.66, 0.38)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(68)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm_layer.add_child(panel)

	mm_marker_root = Control.new()
	mm_marker_root.size = Vector2(136, 136)
	mm_marker_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(mm_marker_root)

	mm_player_dot = ColorRect.new()
	mm_player_dot.color = Color(1, 0.96, 0.55)
	mm_player_dot.size = Vector2(7, 7)
	mm_player_dot.z_index = 5
	mm_marker_root.add_child(mm_player_dot)

	mm_info = _ltr(Label.new())
	mm_info.anchor_left = 1.0
	mm_info.anchor_right = 1.0
	mm_info.offset_left = -260
	mm_info.offset_right = -10
	mm_info.offset_top = 156
	mm_info.offset_bottom = 248
	mm_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mm_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mm_info.add_theme_font_override("font", ui_font)
	mm_info.add_theme_font_size_override("font_size", 11)
	mm_info.add_theme_color_override("font_color", Color(1, 0.96, 0.85))
	mm_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	mm_info.add_theme_constant_override("outline_size", 4)
	mm_layer.add_child(mm_info)


func _mm_dot(cell: Vector2i, col: Color, size: int = 5) -> void:
	var d := ColorRect.new()
	d.color = col
	d.size = Vector2(size, size)
	d.position = mm_off + Vector2(cell.x * TILE * mm_scale, cell.y * TILE * mm_scale)
	mm_marker_root.add_child(d)


func _refresh_minimap() -> void:
	if mm_marker_root == null:
		return
	for c in mm_marker_root.get_children():
		if c != mm_player_dot:
			c.queue_free()
	var world_w := MAP_W
	if scene_id == "dungeon":
		world_w = DUN_W
	elif scene_id == "sea":
		world_w = 17
	# 원(지름 136) 안에 정사각형 맵 전체가 들어가도록 대각 기준으로 축소
	mm_scale = (136.0 * 0.70) / float(world_w * TILE)
	var span := float(world_w * TILE) * mm_scale
	mm_off = Vector2((136.0 - span) * 0.5, (136.0 - span) * 0.5)

	if scene_id == "town":
		# 연못
		for y in range(0, MAP_H, 2):
			for x in range(0, MAP_W, 2):
				if _in_pond(Vector2i(x, y)):
					_mm_dot(Vector2i(x, y), Color(0.40, 0.66, 1.0), 6)
		# 집 / 던전 / 택지
		for h in [HOUSE_SHOP, HOUSE_SMITH, HOUSE_COOK, HOUSE_FISH, HOUSE_CARP]:
			_mm_dot(h, Color(1.0, 0.60, 0.38), 7)
		_mm_dot(CAVE_DOOR, Color(0.55, 0.55, 0.62), 7)
		for p in PLOTS:
			_mm_dot(p, Color(0.92, 0.82, 0.55), 5)
	elif scene_id == "dungeon":
		for y in range(0, DUN_H, 1):
			for x in range(0, DUN_W, 1):
				if dun_grid.size() > y and dun_grid[y][x] == 0:
					_mm_dot(Vector2i(x, y), Color(0.40, 0.38, 0.48), 5)
		_mm_dot(dun_stairs_up, Color(0.55, 0.80, 1.0), 6)
		_mm_dot(dun_stairs_down, Color(1.0, 0.85, 0.45), 6)
	else:
		_mm_dot(Vector2i(6, 4), Color(0.65, 0.48, 0.28), 26)


func _minimap_info() -> String:
	if scene_id == "dungeon":
		var dp := _player_cell()
		return "던전 B%dF / %d층 (%d,%d)" % [dun_floor, DUN_MAX, dp.x, dp.y]
	var p := _player_cell()
	var loc := _fish_location()
	match scene_id:
		"sea":
			return "깊은 바다 (%d,%d)\n낚시터: 배 위" % [p.x, p.y]
		"town":
			var place := "마을 중심가"
			if _near(p, HOUSE_SHOP, 2):
				place = "상점가"
			elif _near(p, HOUSE_SMITH, 2):
				place = "대장간 앞"
			elif _near(p, HOUSE_COOK, 2):
				place = "요리사 집 앞"
			elif _near(p, HOUSE_FISH, 3) or _near(p, Vector2i(PIER_X, PIER_Y1), 3):
				place = "선착장"
			elif _near(p, HOUSE_CARP, 2):
				place = "목수 · 택지"
			elif _near(p, CAVE_DOOR, 3):
				place = "던전 입구"
			elif _is_farm_area(p):
				place = "내 농장"
			elif loc != "":
				place = "물가"
			else:
				# 광장(십자 대로 교차점)인지 확인
				if absi(p.x - 20) <= 3 and absi(p.y - 20) <= 3:
					place = "마을 광장"
				elif p.y == 20:
					place = "마을 대로 (가로)"
				elif p.x == 20:
					place = "마을 대로 (세로)"
			var tail := ""
			if loc != "":
				tail = "낚시 가능: %s" % _fish_spot_name(loc)
			var sk := _top_skill_text()
			if sk != "":
				tail = (tail + "\n" + sk) if tail != "" else sk
			var gz := _gather_hint(p)
			if gz != "":
				tail = (tail + "\n" + gz) if tail != "" else gz
			# 좌표만 덩그러니 보이지 않도록 장소명을 항상 함께 표시한다
			var head := "%s (%d,%d)" % [place, p.x, p.y]
			if tail == "":
				return head
			return "%s\n%s" % [head, tail]
		_:
			return "집 안"


var FARM_X0 := 2
var FARM_Y0 := 2
var FARM_W := 14
var FARM_H := 10


func _is_farm_area(p: Vector2i) -> bool:
	# 플레이어가 농장 구역(마을 서남쪽 밭)에 있는지
	return p.x >= FARM_X0 and p.x < FARM_X0 + FARM_W \
		and p.y >= FARM_Y0 and p.y < FARM_Y0 + FARM_H


func _gather_hint(p: Vector2i) -> String:
	# 내 근처에 채집/채광 노드가 있는지 한 줄로 알려준다.
	var scope := "town" if scene_id == "town" else str(dun_floor)
	var key := "gather" if scope == "town" else "mine"
	var payload: Dictionary = _dict_of(boot.get(key))
	var near := ""
	for n in payload.get("nodes", []):
		var nd: Dictionary = _dict_of(n)
		var d := absi(int(nd.get("x", -99)) - p.x) + absi(int(nd.get("y", -99)) - p.y)
		if d <= 2:
			near = str(nd.get("name", ""))
			break
	if near == "":
		return ""
	return "채집 가능: %s (E)" % near


func _top_skill_text() -> String:
	# 숙련도 중 가장 높은 것을 한 줄로
	var sk: Dictionary = _dict_of(boot.get("skills"))
	if sk.is_empty():
		return ""
	var best_name := ""
	var best_lv := -1
	var parts: Array[String] = []
	for key in sk.keys():
		var s: Dictionary = _dict_of(sk[key])
		var lv := int(s.get("level", 0))
		var nm := str(s.get("name", key))
		parts.append("%s%d" % [nm, lv])
		if lv > best_lv:
			best_lv = lv
			best_name = nm
	if best_name == "":
		return ""
	return "숙련 " + " ".join(parts)


var mm_info_t := 0.0


func _minimap_tick(delta: float) -> void:
	if joy_base != null:
		var active := joy_id >= 0 or touch_dir != Vector2.ZERO
		joy_base.visible = active
		joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE if not active else Control.MOUSE_FILTER_STOP
		if joy_knob != null:
			joy_knob.visible = active
	if fish_btn != null:
		var can_fish := _fish_location() != "" and not panel_open \
			and (dlg_layer == null or not dlg_layer.visible)
		fish_btn.visible = can_fish and fish_state == "idle"
	if mm_player_dot == null:
		return
	mm_player_dot.position = mm_off + (player.position * mm_scale) - Vector2(3, 3)
	mm_info_t -= delta
	if mm_info_t <= 0.0:
		mm_info_t = 0.25
		mm_info.text = _minimap_info()


func _build_dialog() -> void:
	dlg_layer = CanvasLayer.new()
	dlg_layer.layer = 50
	add_child(dlg_layer)
	dlg_box = Panel.new()
	dlg_box.position = Vector2(20, 244)
	dlg_box.size = Vector2(600, 104)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.94, 0.83, 0.98)
	sb.border_color = Color(0.55, 0.36, 0.17)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	dlg_box.add_theme_stylebox_override("panel", sb)
	dlg_box.mouse_filter = Control.MOUSE_FILTER_STOP
	dlg_layer.add_child(dlg_box)

	dlg_face = TextureRect.new()
	dlg_face.position = Vector2(12, 12)
	dlg_face.size = Vector2(84, 84)
	dlg_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dlg_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dlg_box.add_child(dlg_face)

	dlg_name = Label.new()
	dlg_name.position = Vector2(108, 10)
	dlg_name.size = Vector2(360, 22)
	dlg_name.add_theme_font_override("font", ui_font)
	dlg_name.add_theme_font_size_override("font_size", 15)
	dlg_name.add_theme_color_override("font_color", Color(0.44, 0.24, 0.08))
	dlg_box.add_child(dlg_name)

	dlg_body = Label.new()
	dlg_body.position = Vector2(108, 36)
	dlg_body.size = Vector2(392, 62)
	dlg_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_body.add_theme_font_override("font", ui_font)
	dlg_body.add_theme_font_size_override("font_size", 13)
	dlg_body.add_theme_color_override("font_color", Color(0.20, 0.14, 0.08))
	dlg_box.add_child(dlg_body)

	dlg_hint = Label.new()
	dlg_hint.text = "▼ E / 터치"
	dlg_hint.position = Vector2(400, 84)
	dlg_hint.size = Vector2(110, 18)
	dlg_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dlg_hint.add_theme_font_override("font", ui_font)
	dlg_hint.add_theme_font_size_override("font_size", 10)
	dlg_hint.add_theme_color_override("font_color", Color(0.55, 0.36, 0.17))
	dlg_box.add_child(dlg_hint)

	dlg_layer.visible = false


func _say(lines: Array, speaker: String, tex: Texture2D, idx: int, cb: Callable = Callable()) -> void:
	dlg_lines = lines.duplicate()
	dlg_i = 0
	dlg_cb = cb
	dlg_name.text = speaker
	if tex != null:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2((idx % 12) * SRC, (idx / 12) * SRC, SRC, SRC)
		dlg_face.texture = at
	dlg_layer.visible = true
	dlg_box.position = Vector2(20, 400)
	var tw2 := create_tween()
	tw2.tween_property(dlg_box, "position", Vector2(20, 244), 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_show_line()


func _show_line() -> void:
	if dlg_i >= dlg_lines.size():
		_close_dialog()
		return
	dlg_text_full = str(dlg_lines[dlg_i])
	dlg_body.text = dlg_text_full
	dlg_chars = 0.0
	dlg_body.visible_characters = 0
	dlg_typing = true
	dlg_hint.text = "▼ E / 터치"


func _advance_dialog() -> void:
	if dlg_typing:
		dlg_typing = false
		dlg_body.visible_characters = -1
		return
	dlg_i += 1
	if dlg_i >= dlg_lines.size():
		_close_dialog()
	else:
		_show_line()


func _close_dialog() -> void:
	dlg_layer.visible = false
	dlg_typing = false
	var cb := dlg_cb
	dlg_cb = Callable()
	if cb.is_valid():
		cb.call()


func _dlg_tick(delta: float) -> void:
	if dlg_layer == null or not dlg_layer.visible:
		return
	if dlg_typing:
		dlg_chars += delta * 34.0
		if int(dlg_chars) >= dlg_text_full.length():
			dlg_body.visible_characters = -1
			dlg_typing = false
		else:
			dlg_body.visible_characters = int(dlg_chars)
	dlg_hint.visible = not dlg_typing and int(Time.get_ticks_msec() / 400) % 2 == 0


func _build_touch() -> void:
	if not _want_touch():
		return
	var layer := CanvasLayer.new()
	layer.name = "Touch"
	add_child(layer)

	# ── 조이스틱 (왼쪽 아래) ──
	joy_base = Control.new()
	joy_base.name = "JOY"
	var d := joy_r * 2 + 24
	joy_base.size = Vector2(d, d)
	joy_base.anchor_top = 1.0
	joy_base.anchor_bottom = 1.0
	joy_base.offset_left = 22
	joy_base.offset_top = -(d + 26)
	joy_base.offset_right = 22 + d
	joy_base.offset_bottom = -26
	joy_base.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(joy_base)

	var bg := Panel.new()
	bg.size = joy_base.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.08, 0.45)
	sb.border_color = Color(1, 0.94, 0.78, 0.5)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(d / 2))
	bg.add_theme_stylebox_override("panel", sb)
	joy_base.add_child(bg)

	joy_knob = Panel.new()
	joy_knob.size = Vector2(54, 54)
	joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kb := StyleBoxFlat.new()
	kb.bg_color = Color(0.93, 0.86, 0.68, 0.92)
	kb.border_color = Color(0.45, 0.30, 0.14, 0.95)
	kb.set_border_width_all(3)
	kb.set_corner_radius_all(27)
	joy_knob.add_theme_stylebox_override("panel", kb)
	joy_base.add_child(joy_knob)
	_joy_reset_knob()
	joy_base.gui_input.connect(_joy_input)

	# ── 행동 버튼 (오른쪽 아래) ──
	var act := Button.new()
	act.text = "행동"
	act.size = Vector2(96, 96)
	act.anchor_left = 1.0
	act.anchor_right = 1.0
	act.anchor_top = 1.0
	act.anchor_bottom = 1.0
	act.offset_left = -120
	act.offset_right = -24
	act.offset_top = -122
	act.offset_bottom = -26
	act.focus_mode = Control.FOCUS_NONE
	act.add_theme_font_override("font", ui_font)
	act.add_theme_font_size_override("font_size", 18)
	var nb := StyleBoxFlat.new()
	nb.bg_color = Color(0.93, 0.86, 0.68, 0.92)
	nb.border_color = Color(0.45, 0.30, 0.14, 0.95)
	nb.set_border_width_all(4)
	nb.set_corner_radius_all(48)
	act.add_theme_stylebox_override("normal", nb)
	var hb: StyleBoxFlat = nb.duplicate()
	hb.bg_color = Color(1.0, 0.95, 0.8, 1.0)
	act.add_theme_stylebox_override("hover", hb)
	act.add_theme_stylebox_override("pressed", hb)
	act.add_theme_color_override("font_color", Color(0.20, 0.12, 0.05))
	act.button_down.connect(func():
		if panel_open and panel_mode == "fish" and fish_state == "fight":
			fish_touch_hold = true)
	act.button_up.connect(func(): fish_touch_hold = false)
	var fb := Button.new()
	fb.text = "던지기"
	fb.size = Vector2(84, 56)
	fb.anchor_left = 1.0
	fb.anchor_right = 1.0
	fb.anchor_top = 1.0
	fb.anchor_bottom = 1.0
	fb.offset_left = -114
	fb.offset_right = -30
	fb.offset_top = -190
	fb.offset_bottom = -134
	fb.focus_mode = Control.FOCUS_NONE
	fb.visible = false
	fb.add_theme_font_override("font", ui_font)
	fb.add_theme_font_size_override("font_size", 13)
	var fbs := StyleBoxFlat.new()
	fbs.bg_color = Color(0.55, 0.80, 0.95, 0.92)
	fbs.border_color = Color(0.15, 0.35, 0.55, 0.95)
	fbs.set_border_width_all(3)
	fbs.set_corner_radius_all(28)
	fb.add_theme_stylebox_override("normal", fbs)
	fb.add_theme_color_override("font_color", Color(0.08, 0.16, 0.26))
	fb.pressed.connect(func():
		if int(_dict_of(boot.get("stamina")).get("cur", 0)) <= 0:
			_open_panel("fish")
		else:
			_fish_cast())
	layer.add_child(fb)
	fish_btn = fb

	# 모바일 가상 버튼은 반투명하게
	for c in layer.get_children():
		if c is BaseButton or c is Panel:
			(c as CanvasItem).modulate.a = 0.72

	# 기존 원형 버튼은 숨기고 XYAB 로 대체
	if act != null:
		act.visible = false
	if fish_btn != null:
		fish_btn.visible = false
		fish_btn = null

	# XYAB — 오른쪽 아래 다이아몬드 배열
	var cx := 566.0
	var cy := 282.0
	var rr := 36.0
	_xy_button(layer, "Y", Vector2(cx, cy - rr), Color(0.96, 0.78, 0.28), func(): _fish_try())
	_xy_button(layer, "X", Vector2(cx - rr, cy), Color(0.36, 0.62, 0.96), func(): _open_panel("bag"))
	_xy_button(layer, "B", Vector2(cx, cy + rr), Color(0.94, 0.36, 0.32), func(): _close_panel())
	_xy_button(layer, "A", Vector2(cx + rr, cy), Color(0.36, 0.78, 0.45), func(): _interact())

	# 조이스틱은 누르고 있을 때만 보인다
	if joy_base != null:
		joy_base.visible = false
		joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if joy_knob != null:
		joy_knob.visible = false

	act.pressed.connect(func():
		if panel_open and panel_mode == "fish" and fish_state == "fight":
			return
		if panel_open:
			_close_panel()
		else:
			_interact())
	layer.add_child(act)


func _joy_reset_knob() -> void:
	if joy_knob != null:
		joy_knob.position = joy_base.size / 2 - joy_knob.size / 2


func _joy_apply(pos: Vector2) -> void:
	var center := joy_base.size / 2
	var v := pos - center
	if v.length() > joy_r:
		v = v.normalized() * joy_r
	if v.length() < 12.0:
		touch_dir = Vector2.ZERO
		v = Vector2.ZERO
	else:
		touch_dir = v.normalized()
	if joy_knob != null:
		joy_knob.position = center + v - joy_knob.size / 2


func _joy_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and joy_id < 0:
			joy_id = event.index
			_joy_apply(event.position)
		elif not event.pressed and event.index == joy_id:
			joy_id = -1
			touch_dir = Vector2.ZERO
			_joy_reset_knob()
	elif event is InputEventScreenDrag and event.index == joy_id:
		_joy_apply(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			joy_id = 0
			_joy_apply(event.position)
		elif joy_id == 0:
			joy_id = -1
			touch_dir = Vector2.ZERO
			_joy_reset_knob()
	elif event is InputEventMouseMotion and joy_id == 0:
		_joy_apply(event.position)


# ──────────────────────────────────────────── 네트워크(위치 동기화)
func _connect_net() -> void:
	ws = WebSocketPeer.new()
	net_url = _resolve_ws_url()
	ws.connect_to_url(net_url)


func _resolve_ws_url() -> String:
	if OS.has_feature("web"):
		var q: String = str(JavaScriptBridge.eval("location.search", true))
		var re := RegEx.create_from_string("ws=([^&]+)")
		var hit := re.search(q)
		if hit != null:
			return hit.get_string(1).uri_decode()
		var host: String = str(JavaScriptBridge.eval("location.host", true))
		var proto := "wss" if str(JavaScriptBridge.eval("location.protocol", true)) == "https:" else "ws"
		return "%s://%s/ws/game" % [proto, host]
	return "ws://127.0.0.1:8000/ws/game"


func _net_tick(delta: float) -> void:
	if ws == null:
		return
	ws.poll()
	net_state = ws.get_ready_state()
	if net_state == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count() > 0:
			_handle_msg(ws.get_packet().get_string_from_utf8())
		send_acc += delta
		if send_acc >= 0.1:
			send_acc = 0.0
			_send({"t": "pos", "x": player.position.x, "y": player.position.y, "d": facing, "f": 0})
	elif net_state == WebSocketPeer.STATE_CLOSED:
		retry_t += delta
		if retry_t > 3.0:
			retry_t = 0.0
			ws = WebSocketPeer.new()
			ws.connect_to_url(net_url)


func _send(d: Dictionary) -> void:
	if ws == null or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	ws.send_text(JSON.stringify(d))


func _handle_msg(text: String) -> void:
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	match str(data.get("t", "")):
		"hello":
			my_id = str(data.get("id", ""))
			for p in data.get("players", []):
				_spawn_other(str(p.get("id", "")), float(p.get("x", 0)), float(p.get("y", 0)))
			_update_hud()
		"pos":
			var oid := str(data.get("id", ""))
			if oid == "" or oid == my_id:
				return
			if not others.has(oid):
				_spawn_other(oid, float(data.get("x", 0)), float(data.get("y", 0)))
			else:
				others[oid].position = Vector2(float(data.get("x", 0)), float(data.get("y", 0)))
		"leave":
			_remove_other(str(data.get("id", "")))


func _spawn_other(oid: String, x: float, y: float) -> void:
	if oid == "" or others.has(oid):
		return
	var n := CharacterBody2D.new()
	n.position = Vector2(x, y)
	n.z_index = 3
	var s := _sprite(tex_farm, T_PLAYER, Vector2(0, -TILE / 2), 0)
	s.modulate = Color(0.85, 0.92, 1.0)
	n.add_child(s)
	var lbl := Label.new()
	lbl.text = "친구"
	lbl.position = Vector2(-18, -78)
	lbl.add_theme_font_override("font", ui_font)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 3)
	n.add_child(lbl)
	add_child(n)
	others[oid] = n
	_update_hud()


func _remove_other(oid: String) -> void:
	var n: Node2D = others.get(oid, null)
	if n != null:
		n.queue_free()
		others.erase(oid)
		_update_hud()
