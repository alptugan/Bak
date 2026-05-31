import pygame
import time
import random
import vlc


# Initialize Pygame
pygame.init()

# Set up the screen
#screen_width = int(1080 / 3)
#screen_height = int(1920 / 3)
scale_Fac = 1
screen_width = int(1080 / scale_Fac)
screen_height = int(1920 / scale_Fac)
#screen = pygame.display.set_mode((screen_width, screen_height))
screen = pygame.display.set_mode((screen_width, screen_height), pygame.FULLSCREEN)
pygame.display.get_wm_info()
pygame.display.set_caption("window")
win_id = pygame.display.get_wm_info()['window']

# FontName 1
fontCubano = "assets/Fonts/CUBANO/Cubano.ttf"
fontDin = "assets/Fonts/DIN/DIN BoldItalic.ttf"

# Images
bgGamePlaySrc = "assets/02_RISE_INACTION.png"
bgGameEndSrc1 = "assets/03_1Oyunbitti.png"
bgGameEndSrc2 = "assets/03_2 Harikasin.png"
bgGameEndSrc3 = "assets/05_RISE_Outro.png"

# score
score = 0

# Load Videos
video_idle = "assets/01_RISE_INTRO_NOCAMP.mp4"
video_start = "assets/00_RISE_IDLE_NOCAMP.mp4"
vlc_args = "--no-xlib"
vlc_instance = vlc.Instance(vlc_args)
player = vlc_instance.media_player_new()
#media = vlc_instance.media_new(video_start)              # Load the video file
#media_player.set_media(media)                            # Set video
#media_player.set_xwindow(screen.get_wm_info()["window"])
#media_player.play()

# Load Image
bgGamePlay = pygame.image.load(bgGamePlaySrc)
bgGamePlay = pygame.transform.scale(bgGamePlay, (screen_width, screen_height))

# Game End 1
bgGameEnd1 = pygame.image.load(bgGameEndSrc1)
bgGameEnd1 = pygame.transform.scale(bgGameEnd1, (screen_width, screen_height))

# Game End 2
bgGameEnd2 = pygame.image.load(bgGameEndSrc2)
bgGameEnd2 = pygame.transform.scale(bgGameEnd2, (screen_width, screen_height))

# Game End 3
bgGameEnd3 = pygame.image.load(bgGameEndSrc3)
bgGameEnd3 = pygame.transform.scale(bgGameEnd3, (screen_width, screen_height))


# Colors
black = (0, 0, 0)
brown = (85, 38, 3)
orange = (241, 94, 28)
white = (255, 255, 255)

# Fonts
countdown_font = pygame.font.Font(fontCubano, 150 // scale_Fac)
score_font = pygame.font.Font(fontCubano, 150 // scale_Fac)

# Function to render countdown text on the left top
def render_countdown(count):
    screen.fill(black)  # Clear the screen
    # BACKGROUND
    screen.blit(bgGamePlay, (0, 0))

    # REMAINING TIME
    minutes = count // 60
    seconds = count % 60
    countdown_text = countdown_font.render("{:02d}:{:02d}".format(minutes, seconds), True, brown)
    countdown_rect = countdown_text.get_rect()
    countdown_rect.x = screen_width // 2 - countdown_rect.width // 2
    countdown_rect.y = 216 // scale_Fac
    screen.blit(countdown_text, countdown_rect)

    # SCORE
    score_text = score_font.render(str(score), True, orange)
    score_rect = score_text.get_rect()
    score_rect.x = screen_width // 2 - score_rect.width // 2
    score_rect.y = screen_height // 2 - score_rect.height // 2 + (45 // scale_Fac)
    screen.blit(score_text, score_rect)

    pygame.display.update()

def render_GameEnd():
    global score
    screen.fill(black)  # Clear the screen

    # BACKGROUND 1
    screen.blit(bgGameEnd1, (0, 0))
    pygame.display.update()

    pygame.time.wait(1000)

    # BACGROUND WITH SCORE
    screen.blit(bgGameEnd2, (0, 0))
    # Score Font size
    score_font = pygame.font.Font(fontCubano, 300 // scale_Fac)
    score_text = score_font.render(str(score), True, orange)
    score_rect = score_text.get_rect()
    score_rect.x = screen_width // 2 - score_rect.width // 2
    score_rect.y = screen_height - score_rect.height - (300 // scale_Fac)
    screen.blit(score_text, score_rect)
    pygame.display.update()

    pygame.time.wait(1000)

    # BACKGROUND GOODBYE
    screen.blit(bgGameEnd3, (0, 0))
    pygame.display.update()


# Function to display the final score in the middle of the screen
def display_final_score(score):
    screen.fill(black)
    score_text = score_font.render("Final Score: " + str(score), True, orange)
    score_rect = score_text.get_rect()
    score_rect.center = (screen_width // 2, screen_height // 2)
    screen.blit(score_text, score_rect)
    pygame.display.update()

# Function to start countdown
def start_countdown():
    global score
    score = 0
    count = 10
    while count > 0:
        screen.fill(black)
        render_countdown(count)
        #render_score(0)
        pygame.time.wait(1000)
        count -= 1

    screen.fill(black)
    score = random.randint(0, 100)
    render_GameEnd()

    pygame.display.update()
    time.sleep(1)
    #display_final_score(0)

# Function to play video using VLC
def play_video(file_path):
    #global player, vlc_instance, screen
    media = vlc_instance.media_new(file_path)

    player.set_xwindow(win_id)

    #vlc_instance = vlc.Instance()
    #player = vlc_instance.media_player_new()
    player.set_media(media)

    #player.set_xwindow(screen.get_wm_info()["window"])
    #player.set_hwnd(screen.get_wm_info()["window"])  # Use set_hwnd instead of set_xwindow

    player.play()

    # Wait for the video to finish playing
    while True:
        state = player.get_state()
        if state == vlc.State.Ended:
            break

    player.stop()
    start_countdown()


# Game loop
def game_loop():
    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False

        play_video(video_start)

    pygame.quit()
    player.stop()
    player.release()
    vlc_instance.release()

# Run the game loop
game_loop()