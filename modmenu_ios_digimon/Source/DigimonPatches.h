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
#define DG_FLAG_RVA   0x9743000ULL   // 1.2 (era 0x9727000 na 1.1.1)

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

// Diagnostico para o menu (base, flag, estado).
+ (NSString *)diagnostico;

@end
