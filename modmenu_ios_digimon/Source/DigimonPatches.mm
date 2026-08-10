// ============================================================================
// Digimon iOS - liga/desliga de todas as features por flag (ver .h)
// ============================================================================

#import "DigimonPatches.h"
#import "../utils/libtitanox/libtitanox/libtitanox.h"
#import "../utils/libtitanox/utils/utils.h"   // THLog (varargs corretos)

#define DGLOG(...) THLog(__VA_ARGS__)

static const uint64_t k_flag_rva[DGF_TOTAL] = {
    DG_FLAG_DANO, DG_FLAG_CADENCIA, DG_FLAG_EVADE, DG_FLAG_VELOCIDADE, DG_FLAG_ANUNCIO
};
static const char *k_nome[DGF_TOTAL] = {
    "Dano do jogador + Modo Deus (inimigo 0)",
    "Cadencia de ataque (0.1s)",
    "Nunca errar",
    "Velocidade 10x",
    "Recompensa sem assistir anuncio",
};

static uint64_t           g_base = 0;
static volatile uint8_t  *g_flag[DGF_TOTAL] = {0};
static volatile uint32_t *g_mult = NULL;
static BOOL               g_ok   = NO;
static NSString          *g_erro = nil;

@implementation DigimonPatches

+ (void)inicializar {
    g_base = [TitanoxHook getBaseAddressOfLibrary:DG_IMAGE_NAME];
    DGLOG(@"[DG] base de %s = 0x%llx", DG_IMAGE_NAME, (unsigned long long)g_base);
    if (g_base == 0) {
        g_erro = @"UnityFramework nao encontrado no processo";
        DGLOG(@"[DG] ERRO: %@", g_erro);
        return;
    }
    for (int i = 0; i < DGF_TOTAL; i++)
        g_flag[i] = (volatile uint8_t *)(uintptr_t)(g_base + k_flag_rva[i]);
    g_mult = (volatile uint32_t *)(uintptr_t)(g_base + DG_MULT_DANO);

    // leitura de teste (slack do __DATA e R/W; acesso direto, sem mach_vm_*)
    uint8_t s = *g_flag[DGF_DANO];
    (void)s;
    g_ok = YES;
    DGLOG(@"[DG] flags ok | dano=%u cad=%u evade=%u velo=%u ads=%u | mult=%u",
          (unsigned)*g_flag[DGF_DANO], (unsigned)*g_flag[DGF_CADENCIA],
          (unsigned)*g_flag[DGF_EVADE], (unsigned)*g_flag[DGF_VELOCIDADE],
          (unsigned)*g_flag[DGF_ANUNCIO], (unsigned)*g_mult);
}

+ (BOOL)valido { return g_ok; }

+ (const char *)nome:(DgFeat)f {
    if (f < 0 || f >= DGF_TOTAL) return "?";
    return k_nome[f];
}

+ (BOOL)ligada:(DgFeat)f {
    if (!g_ok || f < 0 || f >= DGF_TOTAL) return NO;
    return (*g_flag[f] == 0) ? YES : NO;
}

+ (BOOL)definir:(DgFeat)f ligada:(BOOL)on {
    if (!g_ok || f < 0 || f >= DGF_TOTAL) return NO;
    uint8_t alvo = on ? 0 : 1;
    *g_flag[f] = alvo;
    __sync_synchronize();
    BOOL ok = (*g_flag[f] == alvo);
    DGLOG(@"[DG] %s -> %s %s", k_nome[f], on ? "LIGADO" : "DESLIGADO",
          ok ? "OK" : "FALHOU");
    if (!ok) g_erro = @"escrita de flag nao confirmada";
    return ok;
}

+ (int)danoMultiplicador {
    if (!g_ok) return 1000;
    uint32_t m = *g_mult;
    return (m == 0) ? 1000 : (int)m;
}

+ (BOOL)definirMultiplicador:(int)m {
    if (!g_ok) return NO;
    if (m < 1) m = 1;
    *g_mult = (uint32_t)m;
    __sync_synchronize();
    BOOL ok = ((int)*g_mult == m);
    DGLOG(@"[DG] multiplicador -> %d %s", (int)*g_mult, ok ? "OK" : "FALHOU");
    return ok;
}

+ (NSString *)diagnostico {
    if (!g_ok) {
        return [NSString stringWithFormat:@"base 0x%llx | flags inacessiveis%@",
                (unsigned long long)g_base,
                g_erro ? [@" | " stringByAppendingString:g_erro] : @""];
    }
    return [NSString stringWithFormat:
            @"base 0x%llx | dano=%@ x%d | cad=%@ | evade=%@ | velo=%@ | ads=%@",
            (unsigned long long)g_base,
            (*g_flag[DGF_DANO]==0)?@"on":@"off", [DigimonPatches danoMultiplicador],
            (*g_flag[DGF_CADENCIA]==0)?@"on":@"off",
            (*g_flag[DGF_EVADE]==0)?@"on":@"off",
            (*g_flag[DGF_VELOCIDADE]==0)?@"on":@"off",
            (*g_flag[DGF_ANUNCIO]==0)?@"on":@"off"];
}

@end
