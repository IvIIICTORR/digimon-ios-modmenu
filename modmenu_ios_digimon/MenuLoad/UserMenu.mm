// ============================================================================
// Digimon iOS - conteudo do menu
//
// Um unico toggle: DANO x1000 + MODO DEUS. Ele escreve uma flag de 1 byte na
// memoria GRAVAVEL do jogo (slack do __DATA) - o stub condicional injetado no
// binario (patch_ios_digimon.py) le essa flag e decide. NAO ha escrita de
// codigo em runtime, entao nao ha o crash de code signing do iOS 26.
//
// As demais features sao patch estatico SEMPRE ligado (sem toggle).
// ============================================================================

#include "Includes.h"
#include "../Source/DigimonPatches.h"

static bool s_on[DGF_TOTAL] = {false};
static bool s_inic   = false;
static bool s_falha  = false;

static void SincronizarEstadoInicial()
{
    if (s_inic) return;
    [DigimonPatches inicializar];
    for (int i = 0; i < DGF_TOTAL; i++)
        s_on[i] = [DigimonPatches ligada:(DgFeat)i] ? true : false;
    s_inic = true;
}

void UserMenu::DrawMenu()
{
    SincronizarEstadoInicial();

    ImVec2 WindowSize = ImVec2(330, 300);
    ImGui::SetNextWindowSize(WindowSize, ImGuiCond_Once);
    ImVec2 WindowPosition = ImVec2((SCREEN_WIDTH - WindowSize.x) / 2,
                                   (SCREEN_HEIGHT - WindowSize.y) / 2);
    ImGui::SetNextWindowPos(WindowPosition, ImGuiCond_Once);

    ImGuiWindowFlags WindowFlags = KTempVars.MoveMenu
        ? ImGuiWindowFlags_NoCollapse
        : ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove;

    // ImGui exige End() sempre, mesmo com Begin()==false (senao corrompe a pilha
    // de janelas com -DNDEBUG).
    bool aberta = ImGui::Begin("Digimon Mod", NULL, WindowFlags);
    if (aberta)
    {
        ImGuiWindow* w = ImGui::GetCurrentWindow();
        KTempVars.MenuSize   = w->Size;
        KTempVars.MenuOrigin = w->Pos;

        if (ImGui::CollapsingHeader("CHEATS (liga/desliga)", ImGuiTreeNodeFlags_DefaultOpen))
        {
            if (![DigimonPatches valido]) {
                ImGui::TextColored(ImVec4(1.0f, 0.4f, 0.4f, 1.0f),
                                   "flags inacessiveis (versao do jogo diferente?)");
            } else {
                for (int i = 0; i < DGF_TOTAL; i++) {
                    const char *nome = [DigimonPatches nome:(DgFeat)i];
                    if (ImGui::Checkbox(nome, &s_on[i])) {
                        if (![DigimonPatches definir:(DgFeat)i ligada:(s_on[i] ? YES : NO)]) {
                            s_on[i] = [DigimonPatches ligada:(DgFeat)i] ? true : false;
                            s_falha = true;
                        }
                    }
                    // Logo abaixo do DANO: presets do multiplicador.
                    if (i == DGF_DANO) {
                        int atual = [DigimonPatches danoMultiplicador];
                        ImGui::Indent();
                        ImGui::TextDisabled("Multiplicador do meu dano (atual: x%d)", atual);
                        static const int presets[] = {2, 5, 10, 20, 1000, 9999, 9999999};
                        const int nps = (int)(sizeof(presets)/sizeof(presets[0]));
                        for (int k = 0; k < nps; k++) {
                            char lbl[16]; snprintf(lbl, sizeof(lbl), "x%d", presets[k]);
                            bool ativo = (atual == presets[k]);
                            if (ativo) ImGui::PushStyleColor(ImGuiCol_Button,
                                                             ImVec4(0.20f, 0.55f, 0.25f, 1.0f));
                            if (ImGui::Button(lbl, ImVec2(72, 0))) {
                                if (![DigimonPatches definirMultiplicador:presets[k]]) s_falha = true;
                            }
                            if (ativo) ImGui::PopStyleColor();
                            // 3 por linha (quebra apos cada 3, exceto no ultimo)
                            if (((k + 1) % 3) != 0 && k != nps - 1) ImGui::SameLine();
                        }
                        ImGui::Unindent();
                        ImGui::Spacing();
                    }
                }
            }
        }

        ImGui::Separator();
        if (ImGui::CollapsingHeader("DIAGNOSTICO"))
        {
            ImGui::TextWrapped("%s", [[DigimonPatches diagnostico] UTF8String]);
            if (s_falha) {
                ImGui::TextColored(ImVec4(1.0f, 0.4f, 0.4f, 1.0f),
                                   "falha ao escrever a flag");
            }
            ImGui::TextDisabled("log: Documents/TITANOX_LOGS.txt");
        }

        ImGui::Spacing();
        ImGui::Checkbox("Mover menu", &KTempVars.MoveMenu);
    }
    ImGui::End();
}

void UserMenu::RenderingMenu()
{
    // Sem ESP/overlay: os cheats sao patches no binario.
}

static char consoleBuffer[2048] = "";

void UserMenu::ShowOutputTextbox()
{
    ImGui::InputTextMultiline("Output", consoleBuffer, sizeof(consoleBuffer),
                              ImVec2(ImGui::GetWindowContentRegionMax().x - 10,
                                     ImGui::GetWindowContentRegionMax().y - 30),
                              ImGuiInputTextFlags_ReadOnly);
}

void UserMenu::AppendToOutput(const std::string& text)
{
    strncat(consoleBuffer, (text + "\n").c_str(),
            sizeof(consoleBuffer) - strlen(consoleBuffer) - 1);
}

void UserMenu::ConsoleMenu()
{
    if (!KTempVars.console) return;
    ImGuiWindowFlags WFlags = ImGuiWindowFlags_NoTitleBar |
                              ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove;
    ImVec2 WS = ImVec2(340, 260);
    ImGui::SetNextWindowSize(WS, ImGuiCond_Once);
    ImVec2 WP = ImVec2((SCREEN_WIDTH - WS.x) / 2, (SCREEN_HEIGHT - WS.y) / 2);
    ImGui::SetNextWindowPos(WP, ImGuiCond_Once);

    ImGui::Begin("Console", nullptr, WFlags);
    ShowOutputTextbox();
    if (ImGui::Button("Diagnostico")) {
        AppendToOutput([[DigimonPatches diagnostico] UTF8String]);
    }
    ImGui::SameLine();
    if (ImGui::Button("Fechar")) { KTempVars.console = false; }
    ImGui::End();
}

void UserMenu::Initialize()
{
    if (!KTempVars.console) DrawMenu();
    RenderingMenu();
    ConsoleMenu();
}
