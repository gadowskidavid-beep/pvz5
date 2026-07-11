using Godot;
using System.Collections.Generic;

// Botanik-Labor — spielbarer Rasen-Slice (Godot 4 / C#)
// Alles wird per Code gezeichnet (_Draw) und aktualisiert (_Process),
// damit das Projekt ohne komplizierte Szenen sofort läuft.
public partial class Main : Node2D
{
    // ---- Raster ----
    const int Rows = 5, Cols = 9, Cell = 100;
    const int LawnX = 120, LawnY = 110;

    enum PType { Sunflower, Peashooter, Wallnut }

    class Plant { public PType Type; public int Row, Col; public float X, Y; public float Hp, MaxHp; public float T; }
    class Zombie { public int Row; public float X, Y; public float Hp, MaxHp; public float Speed; }
    class Pea { public int Row; public float X, Y; public float Vx, Dmg; }
    class SunTok { public float X, Y, TargetY, Vy; public int Value; public bool Falling; public float Life; }

    readonly List<Plant> _plants = new();
    readonly List<Zombie> _zombies = new();
    readonly List<Pea> _peas = new();
    readonly List<SunTok> _suns = new();
    readonly System.Random _rng = new();

    int _sun = 75;
    int _wave = 0;
    string _phase = "prep";          // "prep" oder "fight"
    PType _selected = PType.Sunflower;
    int _toSpawn = 0;
    float _spawnTimer = 0f, _skyTimer = 5f;
    string _msg = "";
    float _msgT = 0f;

    Label _hud, _hint;

    public override void _Ready()
    {
        _hud = new Label { Position = new Vector2(20, 12) };
        _hud.AddThemeFontSizeOverride("font_size", 20);
        AddChild(_hud);

        _hint = new Label { Position = new Vector2(20, 630) };
        _hint.AddThemeFontSizeOverride("font_size", 14);
        _hint.Text = "Tasten: [1] Sonnenblume  [2] Erbsenschuetze  [3] Wal-Nuss   |   Klick = setzen / Sonne sammeln   |   [Leertaste] Welle starten";
        AddChild(_hint);
    }

    public override void _Process(double delta)
    {
        float dt = (float)delta;
        UpdateGame(dt);
        UpdateHud();
        QueueRedraw();
    }

    void UpdateGame(float dt)
    {
        if (_msgT > 0) _msgT -= dt;

        // Himmels-Sonne
        _skyTimer -= dt;
        if (_skyTimer <= 0)
        {
            _skyTimer = 8f + (float)_rng.NextDouble() * 4f;
            float x = LawnX + 40 + (float)_rng.NextDouble() * (Cols * Cell - 80);
            _suns.Add(new SunTok { X = x, Y = LawnY - 10, TargetY = LawnY + 50 + (float)_rng.NextDouble() * (Rows * Cell - 120), Vy = 70, Value = 25, Falling = true, Life = 12 });
        }

        // Wellensteuerung
        if (_phase == "fight")
        {
            _spawnTimer -= dt;
            if (_toSpawn > 0 && _spawnTimer <= 0)
            {
                _spawnTimer = 1.2f + (float)_rng.NextDouble() * 1.4f;
                SpawnZombie();
                _toSpawn--;
            }
            if (_toSpawn <= 0 && _zombies.Count == 0)
            {
                _phase = "prep";
                _msg = $"Welle {_wave} geschafft!"; _msgT = 2f;
            }
        }

        // Pflanzen
        foreach (var p in _plants)
        {
            p.T += dt;
            if (p.Type == PType.Sunflower)
            {
                if (p.T >= 6f) { p.T = 0; _suns.Add(new SunTok { X = p.X, Y = p.Y, TargetY = p.Y, Vy = 0, Value = 25, Falling = false, Life = 12 }); }
            }
            else if (p.Type == PType.Peashooter)
            {
                bool ahead = _zombies.Exists(z => z.Row == p.Row && z.X > p.X);
                if (p.T >= 1.4f && ahead) { p.T = 0; _peas.Add(new Pea { Row = p.Row, X = p.X + 22, Y = p.Y - 6, Vx = 380, Dmg = 25 }); }
            }
        }

        // Erbsen
        for (int i = _peas.Count - 1; i >= 0; i--)
        {
            var pe = _peas[i];
            pe.X += pe.Vx * dt;
            if (pe.X > LawnX + Cols * Cell + 20) { _peas.RemoveAt(i); continue; }
            Zombie hit = _zombies.Find(z => z.Row == pe.Row && z.Hp > 0 && Mathf.Abs(z.X - pe.X) < 26);
            if (hit != null) { hit.Hp -= pe.Dmg; _peas.RemoveAt(i); }
        }

        // Zombies
        for (int i = _zombies.Count - 1; i >= 0; i--)
        {
            var z = _zombies[i];
            if (z.Hp <= 0) { _zombies.RemoveAt(i); continue; }
            Plant tgt = _plants.Find(p => p.Row == z.Row && Mathf.Abs(z.X - p.X) < Cell * 0.42f && z.X >= p.X - Cell * 0.2f);
            if (tgt != null)
            {
                tgt.Hp -= 40f * dt;
                if (tgt.Hp <= 0) _plants.Remove(tgt);
            }
            else { z.X -= z.Speed * dt; }
            if (z.X < LawnX - 6) { LoseRun(); return; }
        }

        // Sonne (fallen + verfallen)
        for (int i = _suns.Count - 1; i >= 0; i--)
        {
            var s = _suns[i];
            if (s.Falling && s.Y < s.TargetY) s.Y += s.Vy * dt; else s.Falling = false;
            s.Life -= dt;
            if (s.Life <= 0) _suns.RemoveAt(i);
        }
    }

    void SpawnZombie()
    {
        int row = _rng.Next(Rows);
        float hp = 200 + _wave * 25;
        _zombies.Add(new Zombie { Row = row, X = LawnX + Cols * Cell + 20, Y = LawnY + row * Cell + Cell / 2f, Hp = hp, MaxHp = hp, Speed = 22 + _wave });
    }

    void StartWave()
    {
        if (_phase != "prep") return;
        _wave++;
        _phase = "fight";
        _toSpawn = 4 + _wave * 2;
        _spawnTimer = 0.6f;
        _msg = $"Welle {_wave} startet!"; _msgT = 1.5f;
    }

    void LoseRun()
    {
        _msg = "Ueberrannt! Neustart."; _msgT = 2.5f;
        _plants.Clear(); _zombies.Clear(); _peas.Clear(); _suns.Clear();
        _sun = 75; _wave = 0; _phase = "prep";
    }

    static int CostOf(PType t) => t == PType.Peashooter ? 100 : 50;

    void TryPlace(int col, int row)
    {
        if (col < 0 || col >= Cols || row < 0 || row >= Rows) return;
        if (_plants.Exists(p => p.Col == col && p.Row == row)) return;
        int cost = CostOf(_selected);
        if (_sun < cost) { _msg = "Zu wenig Sonne!"; _msgT = 1.2f; return; }
        _sun -= cost;
        float x = LawnX + col * Cell + Cell / 2f;
        float y = LawnY + row * Cell + Cell / 2f;
        float hp = _selected == PType.Wallnut ? 400 : 60;
        _plants.Add(new Plant { Type = _selected, Row = row, Col = col, X = x, Y = y, Hp = hp, MaxHp = hp, T = 0 });
    }

    public override void _UnhandledInput(InputEvent ev)
    {
        if (ev is InputEventKey k && k.Pressed && !k.Echo)
        {
            if (k.Keycode == Key.Key1) _selected = PType.Sunflower;
            else if (k.Keycode == Key.Key2) _selected = PType.Peashooter;
            else if (k.Keycode == Key.Key3) _selected = PType.Wallnut;
            else if (k.Keycode == Key.Space || k.Keycode == Key.Enter) StartWave();
        }
        else if (ev is InputEventMouseButton mb && mb.Pressed && mb.ButtonIndex == MouseButton.Left)
        {
            Vector2 pos = mb.Position;
            for (int i = _suns.Count - 1; i >= 0; i--)
            {
                if (pos.DistanceTo(new Vector2(_suns[i].X, _suns[i].Y)) < 30) { _sun += _suns[i].Value; _suns.RemoveAt(i); return; }
            }
            int col = (int)((pos.X - LawnX) / Cell);
            int row = (int)((pos.Y - LawnY) / Cell);
            TryPlace(col, row);
        }
    }

    void UpdateHud()
    {
        string sel = _selected switch
        {
            PType.Sunflower => "Sonnenblume (50)",
            PType.Peashooter => "Erbsenschuetze (100)",
            _ => "Wal-Nuss (50)"
        };
        string ph = _phase == "fight" ? $"Welle {_wave} laeuft..."
                  : (_wave == 0 ? "Bereit - [Leertaste] fuer Welle 1" : $"Welle {_wave} geschafft - [Leertaste] fuer naechste");
        _hud.Text = $"Sonne: {_sun}    |    Gewaehlt: {sel}    |    {ph}" + (_msgT > 0 ? $"    ->  {_msg}" : "");
    }

    public override void _Draw()
    {
        // Rasen
        for (int r = 0; r < Rows; r++)
            for (int c = 0; c < Cols; c++)
            {
                Color g = ((r + c) % 2 == 0) ? new Color(0.23f, 0.42f, 0.25f) : new Color(0.27f, 0.49f, 0.29f);
                DrawRect(new Rect2(LawnX + c * Cell, LawnY + r * Cell, Cell, Cell), g);
            }
        // Haus / linke Kante
        DrawRect(new Rect2(LawnX - 12, LawnY, 8, Rows * Cell), new Color(0.42f, 0.32f, 0.62f));

        // Pflanzen
        foreach (var p in _plants)
        {
            Color col = p.Type switch
            {
                PType.Sunflower => new Color(1f, 0.83f, 0.2f),
                PType.Peashooter => new Color(0.3f, 0.8f, 0.35f),
                _ => new Color(0.6f, 0.42f, 0.24f)
            };
            DrawCircle(new Vector2(p.X, p.Y), 30, col);
            DrawHpBar(p.X, p.Y + 34, p.Hp / p.MaxHp, new Color(0.3f, 0.85f, 0.35f));
        }
        // Erbsen
        foreach (var pe in _peas) DrawCircle(new Vector2(pe.X, pe.Y), 7, new Color(0.62f, 0.95f, 0.4f));
        // Zombies
        foreach (var z in _zombies)
        {
            DrawRect(new Rect2(z.X - 22, z.Y - 34, 44, 64), new Color(0.5f, 0.55f, 0.5f));
            DrawHpBar(z.X, z.Y - 42, z.Hp / z.MaxHp, new Color(0.9f, 0.3f, 0.3f));
        }
        // Sonne
        foreach (var s in _suns) DrawCircle(new Vector2(s.X, s.Y), 16, new Color(1f, 0.85f, 0.25f));
    }

    void DrawHpBar(float cx, float y, float frac, Color c)
    {
        if (frac >= 1f) return;
        frac = Mathf.Clamp(frac, 0f, 1f);
        float w = 46, h = 5;
        DrawRect(new Rect2(cx - w / 2f, y, w, h), new Color(0, 0, 0, 0.5f));
        DrawRect(new Rect2(cx - w / 2f, y, w * frac, h), c);
    }
}
