// ============================================================================
// Digimon iOS - conteudo do menu
//
// Cada checkbox chama DigimonPatches, que escreve na memoria os bytes do stub
// (ligar) ou os originais (desligar). Ver Source/DigimonPatches.h.
//
// OBJETIVO DESTA PRIMEIRA VERSAO: provar que o liga/desliga funciona em app
// sideloaded, sem JIT. Por isso a aba DIAGNOSTICO mostra base, alvos validos e
// o resultado real da escrita - se falhar, precisa aparecer o motivo, nao um
// checkbox que se move sem efeito.
// ============================================================================

#include "Includes.h"
#include "../Source/DigimonPatches.h"

// Estado dos checkboxes. Comeca espelhando o que foi lido da memoria em
// DigimonPatches::inicializar (o IPA e distribuido JA patchado, entao o normal
// e comecar tudo ligado).
static bool s_ligado[DG_TOTAL] = {false};
static bool s_iniciado = false;
static bool s_ultimaFalha = false;

static void SincronizarEstadoInicial()
{
    if (s_iniciado) return;
    [DigimonPatches inicializar];
    for (int i = 0; i < DG_TOTAL; i++) {
        s_ligado[i] = [DigimonPatches estaLigada:(DgFeature)i] ? true : false;
    }
    s_iniciado = true;
}

// Desenha um checkbox e aplica a mudanca. Se o alvo nao validou, mostra
// desabilitado - melhor do que deixar o usuario clicar em algo inerte.
static void FeatureCheckbox(DgFeature f)
{
    const char *nome = [DigimonPatches nome:f];
    bool valido = [DigimonPatches valida:f] ? true : false;

    if (!valido) {
        ImGui::BeginDisabled();
        bool falso = false;
        ImGui::Checkbox(nome, &falso);
        ImGui::EndDisabled();
        ImGui::SameLine();
        ImGui::TextColored(ImVec4(1.0f, 0.4f, 0.4f, 1.0f), "(nao validado)");
        return;
    }

    if (ImGui::Checkbox(nome, &s_ligado[f])) {
        BOOL ok = [DigimonPatches definir:f ligada:(s_ligado[f] ? YES : NO)];
        if (!ok) {
            // Reverter o visual: o checkbox nao pode mentir sobre o estado real.
            s_ligado[f] = [DigimonPatches estaLigada:f] ? true : false;
            s_ultimaFalha = true;
        }
    }
}

void UserMenu::DrawMenu()
{
    SincronizarEstadoInicial();

    ImVec2 WindowSize = ImVec2(340, 330);
    ImGui::SetNextWindowSize(WindowSize, ImGuiCond_Once);

    ImVec2 WindowPosition = ImVec2((SCREEN_WIDTH - WindowSize.x) / 2,
                                   (SCREEN_HEIGHT - WindowSize.y) / 2);
    ImGui::SetNextWindowPos(WindowPosition, ImGuiCond_Once);

    ImGuiWindowFlags WindowFlags = KTempVars.MoveMenu
        ? ImGuiWindowFlags_NoCollapse
        : ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove;

    if (ImGui::Begin("Digimon Mod", NULL, WindowFlags))
    {
        ImGuiWindow* CurrentWindow = ImGui::GetCurrentWindow();
        KTempVars.MenuSize   = CurrentWindow->Size;
        KTempVars.MenuOrigin = CurrentWindow->Pos;

        if (ImGui::CollapsingHeader("COMBATE", ImGuiTreeNodeFlags_DefaultOpen))
        {
            FeatureCheckbox(DG_DANO_E_MODO_DEUS);
            FeatureCheckbox(DG_CADENCIA_ATAQUE);
            FeatureCheckbox(DG_NUNCA_ERRAR);
        }

        if (ImGui::CollapsingHeader("VELOCIDADE", ImGuiTreeNodeFlags_DefaultOpen))
        {
            FeatureCheckbox(DG_VELOCIDADE_X1);
            FeatureCheckbox(DG_VELOCIDADE_X2);
        }

        if (ImGui::CollapsingHeader("BYPASS", ImGuiTreeNodeFlags_DefaultOpen))
        {
            FeatureCheckbox(DG_BYPASS_ANUNCIO);
            ImGui::TextDisabled("nao remove o limite diario");
        }

        ImGui::Separator();

        if (ImGui::CollapsingHeader("DIAGNOSTICO"))
        {
            ImGui::TextWrapped("%s", [[DigimonPatches diagnostico] UTF8String]);
            ImGui::Spacing();
            if ([DigimonPatches escritaSuportada]) {
                ImGui::TextColored(ImVec4(0.4f, 1.0f, 0.4f, 1.0f),
                                   "escrita em runtime: FUNCIONA");
            } else if (s_ultimaFalha) {
                ImGui::TextColored(ImVec4(1.0f, 0.4f, 0.4f, 1.0f),
                                   "escrita recusada: cheats ficam como estao");
            } else {
                ImGui::TextDisabled("mexa num toggle para testar a escrita");
            }
            ImGui::Spacing();
            ImGui::TextDisabled("log: Documents/TITANOX_LOGS.TXT");

            if (ImGui::Button("Ligar tudo")) {
                for (int i = 0; i < DG_TOTAL; i++) {
                    if (![DigimonPatches valida:(DgFeature)i]) continue;
                    if ([DigimonPatches definir:(DgFeature)i ligada:YES])
                        s_ligado[i] = true;
                    else
                        s_ultimaFalha = true;
                }
            }
            ImGui::SameLine();
            if (ImGui::Button("Desligar tudo")) {
                for (int i = 0; i < DG_TOTAL; i++) {
                    if (![DigimonPatches valida:(DgFeature)i]) continue;
                    if ([DigimonPatches definir:(DgFeature)i ligada:NO])
                        s_ligado[i] = false;
                    else
                        s_ultimaFalha = true;
                }
            }
        }

        ImGui::Spacing();
        ImGui::Checkbox("Mover menu", &KTempVars.MoveMenu);

        ImGui::End();
    }
}

void UserMenu::RenderingMenu()
{
    // Sem ESP/overlay de desenho neste projeto: os cheats sao patches no
    // binario, nao precisam de nada desenhado em tela.
}

static char consoleBuffer[4096] = "";

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
    ImVec2 WS = ImVec2(350, 300);
    ImGui::SetNextWindowSize(WS, ImGuiCond_Once);
    ImVec2 WP = ImVec2((SCREEN_WIDTH - WS.x) / 2, (SCREEN_HEIGHT - WS.y) / 2);
    ImGui::SetNextWindowPos(WP, ImGuiCond_Once);

    ImGui::Begin("Console", nullptr, WFlags);

    ImGuiWindow* ConsoleWindow = ImGui::GetCurrentWindow();
    KTempVars.ConsoleSize   = ConsoleWindow->Size;
    KTempVars.ConsoleOrigin = ConsoleWindow->Pos;

    ShowOutputTextbox();

    if (ImGui::Button("Diagnostico")) {
        AppendToOutput([[DigimonPatches diagnostico] UTF8String]);
    }
    ImGui::SameLine();
    if (ImGui::Button("Limpar")) { consoleBuffer[0] = '\0'; }
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
