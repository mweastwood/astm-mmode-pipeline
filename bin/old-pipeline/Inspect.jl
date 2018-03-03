module Inspect

import SFML
using JLD

const dir = "/home/michael/mmode-images/cas"
const files = readdir(dir)
const png_files = filter(file -> endswith(file, ".png"), files)

sort!(png_files)

function inspect(idx = 1)
    if isfile("flags.jld")
        flags = load("flags.jld", "flags")
    else
        flags = zeros(Bool, length(png_files))
    end

    redraw = true
    window = SFML.RenderWindow("Inspect", 724, 724)
    windowsize = SFML.get_size(window)
    texture = SFML.Texture(joinpath(dir, png_files[idx]))
    rectangle = SFML.RectangleShape()
    text = SFML.RenderText()
    SFML.set_string(text, @sprintf("%05d", idx))
    SFML.set_color(text, flags[idx]? SFML.red : SFML.blue)
    try
        fps = 10 # frame rate limit
        time = 1/fps
        running = true
        event = SFML.Event()
        while running
            time < 1/fps && sleep(1/fps-time)
            time = @elapsed begin
                # clear the pending events
                resized = false
                while SFML.pollevent(window, event)
                    if SFML.get_type(event) == SFML.EventType.CLOSED
                        running = false
                    elseif SFML.get_type(event) == SFML.EventType.KEY_PRESSED
                        key_event = SFML.get_key(event)
                        key_code = key_event.key_code
                        if key_code == SFML.KeyCode.RIGHT
                            idx += 1
                            idx > length(png_files) && (idx = 1)
                            texture = SFML.Texture(joinpath(dir, png_files[idx]))
                            SFML.set_string(text, @sprintf("%05d", idx))
                            SFML.set_color(text, flags[idx]? SFML.red : SFML.blue)
                            redraw = true
                        elseif SFML.is_key_pressed(SFML.KeyCode.LEFT)
                            idx -= 1
                            idx < 1 && (idx = length(png_files))
                            texture = SFML.Texture(joinpath(dir, png_files[idx]))
                            SFML.set_string(text, @sprintf("%05d", idx))
                            SFML.set_color(text, flags[idx]? SFML.red : SFML.blue)
                            redraw = true
                        elseif SFML.is_key_pressed(SFML.KeyCode.NUM1)
                            flags[idx] = true
                            idx += 1
                            idx > length(png_files) && (idx = 1)
                            texture = SFML.Texture(joinpath(dir, png_files[idx]))
                            SFML.set_string(text, @sprintf("%05d", idx))
                            SFML.set_color(text, flags[idx]? SFML.red : SFML.blue)
                            redraw = true
                        elseif SFML.is_key_pressed(SFML.KeyCode.NUM0)
                            flags[idx] = false
                            texture = SFML.Texture(joinpath(dir, png_files[idx]))
                            SFML.set_string(text, @sprintf("%05d", idx))
                            SFML.set_color(text, flags[idx]? SFML.red : SFML.blue)
                            redraw = true
                        end
                    elseif SFML.get_type(event) == SFML.EventType.RESIZED
                        windowsize = SFML.get_size(window)
                        view = SFML.View(SFML.FloatRect(0, 0, windowsize.x, windowsize.y))
                        SFML.set_view(window, view)
                        resized = true
                    end
                end

                # draw
                if redraw || resized
                    SFML.clear(window, SFML.black)
                    SFML.set_texture(rectangle, texture)
                    SFML.set_size(rectangle, SFML.Vector2f(windowsize.x, windowsize.y))
                    SFML.draw(window, rectangle)
                    SFML.draw(window, text)
                    SFML.display(window)
                    gc()
                end
            end
        end
    finally
        close(window)
    end

    save("flags.jld", "flags", flags)
end

end

