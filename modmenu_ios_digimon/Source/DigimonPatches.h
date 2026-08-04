#pragma once
// ============================================================================
// Digimon iOS - liga/desliga dos patches em runtime
//
// IDEIA CENTRAL
// Os cheats JA existem como patch estatico dentro do IPA (aplicados offline por
// patch_ios_digimon.py, e testados em jogo). Este arquivo nao cria cheat novo:
// ele guarda os bytes ORIGINAIS de cada alvo e alterna entre
//     bytes originais  = cheat DESLIGADO
//     bytes do stub    = cheat LIGADO
// escrevendo na memoria do proprio processo via Titanox (mach_vm_protect +
// write). Sem Dobby, sem JIT, sem jailbreak.
//
// POR QUE ESSE DESENHO E O SEGURO
// O IPA e distribuido JA PATCHADO. Entao, se a escrita em runtime falhar (a
// duvida real: iOS pode recusar tornar pagina de codigo escrevivel em app
// sideloaded), o estado permanece o de hoje: cheats ligados e funcionando. A
// falha degrada para o comportamento atual, nunca para "jogo quebrado".
//
// Fonte dos offsets e dos bytes: OFFSETS_DIGIMON_IOS.md (dump do proprio IPA).
// Valem SOMENTE para UnityFramework de 162.117.056 bytes (v1.1.1 build 42).
// ============================================================================

#import <Foundation/Foundation.h>
#include <cstdint>
#include <cstddef>

// Nome da imagem alvo dentro do processo (o binario IL2CPP do jogo).
#define DG_IMAGE_NAME "UnityFramework"

typedef enum {
    DG_DANO_E_MODO_DEUS = 0,   // GetTypeDamage: aliado x1000 / inimigo 0
    DG_CADENCIA_ATAQUE,        // GetAttackTime -> 0.1s
    DG_NUNCA_ERRAR,            // CheckDamageEvade -> false
    DG_VELOCIDADE_X1,          // SetGameSpeed: constante do estado X1
    DG_VELOCIDADE_X2,          // SetGameSpeed: constante do estado X2
    DG_BYPASS_ANUNCIO,         // PS_ADView b__0 -> b__3(0)
    DG_TOTAL
} DgFeature;

@interface DigimonPatches : NSObject

// Resolve a base do UnityFramework e confere, para cada alvo, se os bytes na
// memoria batem com o stub OU com o original. Se nao baterem com nenhum dos
// dois, o alvo e marcado como invalido e nunca sera escrito (protecao contra
// versao diferente do jogo).
+ (void)inicializar;

// Estado atual conhecido de cada feature.
+ (BOOL)estaLigada:(DgFeature)f;

// Escreve os bytes do stub (ligar) ou os originais (desligar).
// Devolve NO se a escrita falhou - nesse caso o estado interno nao muda.
+ (BOOL)definir:(DgFeature)f ligada:(BOOL)ligar;

// Nome legivel, para a UI.
+ (const char *)nome:(DgFeature)f;

// Este alvo passou a validacao de bytes?
+ (BOOL)valida:(DgFeature)f;

// Diagnostico para mostrar no menu (base, quantos alvos validos, erro de vm).
+ (NSString *)diagnostico;

// A escrita em memoria de codigo funcionou pelo menos uma vez?
+ (BOOL)escritaSuportada;

@end
