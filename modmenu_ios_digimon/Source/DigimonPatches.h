#pragma once
// ============================================================================
// Digimon iOS - liga/desliga do DANO por FLAG em dado (sem escrever codigo)
//
// POR QUE ASSIM
// iOS 26 (code signing monitor) mata qualquer pagina de CODIGO modificada em
// runtime (crash EXC_BAD_ACCESS "Invalid Page" - comprovado em teste). Entao o
// toggle NAO reescreve codigo. O patcher offline (patch_ios_digimon.py) injeta
// um stub condicional num code cave que LE uma flag de 1 byte no slack GRAVAVEL
// do __DATA. Este dylib so ESCREVE essa flag - escrita em dado, permitida.
//
//   flag == 0  -> dano/god LIGADO   (padrao: o slack sobe zerado)
//   flag != 0  -> dano/god DESLIGADO (roda o dano original do jogo)
//
// As demais features (cadencia, nunca errar, velocidade 2x, bypass de anuncio)
// sao patch estatico SEMPRE ligado - nao tem toggle.
//
// Estes valores TEM de casar com patch_ios_digimon.py:
//   FUNC_GETTYPEDAMAGE = 0x3123D88, CAVE_RVA = 0x085AC040, FLAG_RVA = 0x9743000
// Validos SOMENTE para o UnityFramework v1.2 (162.235.136 bytes).
// ============================================================================

#import <Foundation/Foundation.h>
#include <cstdint>

#define DG_IMAGE_NAME "UnityFramework"
#define DG_FLAG_RVA   0x9743000ULL   // 1.2: flag on/off (1 byte)
#define DG_MULT_RVA   0x9743010ULL   // 1.2: multiplicador do dano (int 4 bytes)

@interface DigimonPatches : NSObject

// Resolve a base do UnityFramework e o endereco da flag. Le o estado inicial.
+ (void)inicializar;

// A base foi resolvida e a flag esta acessivel?
+ (BOOL)valido;

// Dano/God esta ligado agora? (flag == 0)
+ (BOOL)danoLigado;

// Liga (flag=0) ou desliga (flag=1) o dano. Escrita em dado, sem tocar codigo.
// Devolve NO se a base nao foi resolvida ou a releitura nao confirmou.
+ (BOOL)definirDano:(BOOL)ligar;

// Multiplicador do dano do jogador (o cave le este int; 0 -> usa 1000). O modo
// deus (inimigo -> 0) nao depende dele. Escrita em dado.
+ (int)danoMultiplicador;              // valor efetivo atual (0 no slot vira 1000)
+ (BOOL)definirMultiplicador:(int)m;   // escreve o int; devolve NO se inacessivel

// Diagnostico para o menu (base, flag, mult, estado).
+ (NSString *)diagnostico;

@end
