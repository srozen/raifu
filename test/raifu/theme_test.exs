defmodule Raifu.ThemeTest do
  use ExUnit.Case, async: true

  alias Raifu.Theme

  doctest Theme

  test "every theme resolves for both color depths" do
    for name <- Theme.names(), depth <- [:truecolor, :ansi256] do
      palette = Theme.palette(name, depth, 8)

      for color <- [palette.background, palette.panel, palette.accent, Theme.trail(palette, 8)] do
        assert [_ | _] = [Theme.fg(palette, color), Theme.bg(palette, color)]
      end

      assert Theme.life(palette, 1) != Theme.life(palette, Theme.max_age())
      assert Theme.life(palette, 1_000) == Theme.life(palette, Theme.max_age())
    end
  end

  test "the trail fades into the background" do
    palette = Theme.palette(:ember, :truecolor, 8)

    assert distance(Theme.trail(palette, 1), palette.background) >
             distance(Theme.trail(palette, 8), palette.background)
  end

  test "escape codes follow the color depth" do
    assert Theme.fg(Theme.palette(:ember, :truecolor, 8), {255, 176, 64}) == "\e[38;2;255;176;64m"
    assert Theme.bg(Theme.palette(:ember, :ansi256, 8), {255, 176, 64}) == "\e[48;5;215m"
  end

  defp distance({r1, g1, b1}, {r2, g2, b2}), do: abs(r1 - r2) + abs(g1 - g2) + abs(b1 - b2)
end
