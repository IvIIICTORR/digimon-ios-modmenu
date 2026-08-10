#pragma once
// ============================================================================
// Digimon iOS - liga/desliga de TODAS as features por FLAG em dado (iOS 26)
//
// Nao reescreve codigo em runtime (iOS 26 mata pagina de codigo modificada). O
// patcher offline injeta, para cada feature, um stub condicional num code cave
// que LE uma flag de 1 byte no slack gravavel do __DATA. Este dylib so ESCREVE
// essas flags (dado, permitido).
//
//   flag == 0  -> feature LIGADA   (slack sobe zerado = tudo ligado por padrao)
//   flag != 0  -> feature DESLIGADA (roda o comportamento original do jogo)
//
// Alem das flags, o DANO tem um MULTIPLICADOR (int 4 bytes) que o stub le no
// lugar do 1000 fixo. O modo deus (inimigo -> 0) NAO depende do multiplicador.
//
// Enderecos TEM de casar com patch_ios_digimon.py. Validos SOMENTE para o
// UnityFramework v1.2.3 (162.252.112 bytes).
// ============================================================================

#import <Foundation/Foundation.h>
#include <cstdint>

#define DG_IMAGE_NAME "UnityFramework"

// Flags (1 byte, 0=ligado) e multiplicador (int) no slack do __DATA - 1.2.3.
#define DG_FLAG_DANO        0x9747000ULL
#define DG_MULT_DANO        0x9747010ULL
#define DG_FLAG_CADENCIA    0x9747020ULL
#define DG_FLAG_EVADE       0x9747030ULL
#define DG_FLAG_VELOCIDADE  0x9747040ULL
#define DG_FLAG_ANUNCIO     0x9747050ULL

typedef enum {
    DGF_DANO = 0,
    DGF_CADENCIA,
    DGF_EVADE,
    DGF_VELOCIDADE,
    DGF_ANUNCIO,
    DGF_TOTAL
} DgFeat;

@interface DigimonPatches : NSObject

+ (void)inicializar;              // resolve base e ponteiros das flags
+ (BOOL)valido;                   // base + flags acessiveis?
+ (const char *)nome:(DgFeat)f;   // rotulo p/ o menu
+ (BOOL)ligada:(DgFeat)f;         // flag == 0 ?
+ (BOOL)definir:(DgFeat)f ligada:(BOOL)on;   // escreve a flag (dado)

// Multiplicador do dano do jogador (0 no slot -> stub usa 1000).
+ (int)danoMultiplicador;
+ (BOOL)definirMultiplicador:(int)m;

+ (NSString *)diagnostico;

@end
