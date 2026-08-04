// ============================================================================
// Digimon iOS - implementacao do liga/desliga (ver DigimonPatches.h)
// ============================================================================

#import "DigimonPatches.h"
#import "../utils/libtitanox/libtitanox/libtitanox.h"
#import "../utils/libtitanox/utils/utils.h"   // THLog (funcao C, varargs corretos)

#include <mach/mach.h>
#include <mach/vm_map.h>

// ---------------------------------------------------------------------------
// LOG: usar SEMPRE a funcao C THLog(...), NUNCA [TitanoxHook log:...].
//
// O wrapper +[TitanoxHook log:] do template repassa um va_list como se fosse o
// primeiro argumento variadico de THLog (bug de encaminhamento de varargs).
// Com qualquer especificador que dereferencia ponteiro (%s, %@) ele le um
// ponteiro invalido e da SIGSEGV. A funcao C THLog trata os varargs certo.
// Este era o motivo de o jogo fechar ao abrir o menu.
// ---------------------------------------------------------------------------
#define DGLOG(...) THLog(__VA_ARGS__)

// ---------------------------------------------------------------------------
// Tabela de alvos.
//
// Cada entrada guarda RVA, os bytes do STUB (cheat ligado) e os bytes ORIGINAIS
// (cheat desligado). Os originais foram capturados pelo patcher no momento em
// que gravou o IPA - estao no OFFSETS_DIGIMON_IOS.md e no log do patch.
//
// NOTA sobre RVA: no UnityFramework deste jogo o segmento __TEXT tem vmaddr=0,
// entao RVA == offset de arquivo == deslocamento a partir da base carregada.
// A funcao inicializar() confirma isso comparando os bytes.
// ---------------------------------------------------------------------------
typedef struct {
    uint64_t rva;
    const char *nome;
    uint8_t stub[48];       // cheat LIGADO
    uint8_t original[48];   // cheat DESLIGADO
    size_t  tam;
} DgAlvo;

static DgAlvo g_alvos[DG_TOTAL] = {

    // --- GetTypeDamage: aliado x1000 / inimigo 0 (dano + modo deus) ---
    {
        0x3127250, "Dano x1000 + Modo Deus",
        {0x41,0x01,0x00,0xB4, 0x28,0x30,0x40,0xB9, 0x1F,0x19,0x00,0x71,
         0xA2,0x00,0x00,0x54, 0x09,0x7D,0x80,0x52, 0x21,0x01,0x62,0x1E,
         0x00,0x08,0x61,0x1E, 0xC0,0x03,0x5F,0xD6, 0xE0,0x03,0x67,0x9E,
         0xC0,0x03,0x5F,0xD6, 0xC0,0x03,0x5F,0xD6},
        {0xED,0x33,0xBA,0x6D, 0xEB,0x2B,0x01,0x6D, 0xE9,0x23,0x02,0x6D,
         0xF6,0x57,0x03,0xA9, 0xF4,0x4F,0x04,0xA9, 0xFD,0x7B,0x05,0xA9,
         0xFD,0x43,0x01,0x91, 0xF3,0x03,0x02,0xAA, 0x08,0x1C,0xA0,0x4E,
         0xF4,0x03,0x01,0xAA, 0xF5,0x03,0x00,0xAA},
        44
    },

    // --- GetAttackTime -> 0.1s ---
    {
        0x2CDCCDC, "Cadencia de Ataque (0.1s)",
        {0x88,0x0C,0x80,0x52, 0x00,0x01,0x22,0x1E, 0x09,0x7D,0x80,0x52,
         0x21,0x01,0x22,0x1E, 0x00,0x18,0x21,0x1E, 0xC0,0x03,0x5F,0xD6},
        {0xE9,0x23,0xBE,0x6D, 0xFD,0x7B,0x01,0xA9, 0xFD,0x43,0x00,0x91,
         0x00,0x14,0x40,0xF9, 0x20,0x02,0x00,0xB4, 0x61,0x00,0x80,0x52},
        24
    },

    // --- CheckDamageEvade -> false ---
    {
        0x313B66C, "Nunca Errar",
        {0x00,0x00,0x80,0x52, 0xC0,0x03,0x5F,0xD6},
        {0xFF,0x83,0x01,0xD1, 0xE9,0x23,0x03,0x6D},
        8
    },

    // --- SetGameSpeed: constante do estado X1 (1.0 -> 5.0) ---
    {
        0x32AE148, "Velocidade 5x (estado X1)",
        {0x01,0x90,0x22,0x1E},
        {0x01,0x10,0x2E,0x1E},
        4
    },

    // --- SetGameSpeed: constante do estado X2 (2.0 -> 5.0) ---
    {
        0x32AE150, "Velocidade 5x (estado X2)",
        {0x02,0x90,0x22,0x1E},
        {0x02,0x10,0x20,0x1E},
        4
    },

    // --- PS_ADView b__0 -> b__3(0): recompensa sem video ---
    {
        0x2E5D7E4, "Pular Video de Anuncio",
        {0x01,0x00,0x80,0x52, 0xB7,0x00,0x00,0x14},
        {0xF8,0x5F,0xBC,0xA9, 0xF6,0x57,0x01,0xA9},
        8
    },
};

static uint64_t g_base = 0;
static BOOL g_ligada[DG_TOTAL] = {NO};
static BOOL g_valida[DG_TOTAL] = {NO};
static BOOL g_escritaOk = NO;
static BOOL g_iniciado  = NO;
static NSString *g_erro = nil;

@implementation DigimonPatches

+ (const char *)nome:(DgFeature)f {
    if (f < 0 || f >= DG_TOTAL) return "?";
    return g_alvos[f].nome;
}

+ (BOOL)estaLigada:(DgFeature)f {
    if (f < 0 || f >= DG_TOTAL) return NO;
    return g_ligada[f];
}

+ (BOOL)valida:(DgFeature)f {
    if (f < 0 || f >= DG_TOTAL) return NO;
    return g_valida[f];
}

+ (BOOL)escritaSuportada { return g_escritaOk; }

+ (void)inicializar {
    if (g_iniciado) return;      // roda uma unica vez
    g_iniciado = YES;

    DGLOG(@"[DG] inicializar: comecou");

    @try {
        g_base = [TitanoxHook getBaseAddressOfLibrary:DG_IMAGE_NAME];
    } @catch (NSException *e) {
        g_base = 0;
        DGLOG(@"[DG] excecao ao obter base: %@", e.reason);
    }
    DGLOG(@"[DG] base de %s = 0x%llx", DG_IMAGE_NAME, (unsigned long long)g_base);

    if (g_base == 0) {
        g_erro = @"UnityFramework nao encontrado no processo";
        DGLOG(@"[DG] ERRO: %@", g_erro);
        return;
    }

    int validos = 0;
    for (int i = 0; i < DG_TOTAL; i++) {
        DgAlvo *a = &g_alvos[i];
        uint8_t atual[48] = {0};
        mach_vm_address_t addr = (mach_vm_address_t)(g_base + a->rva);

        DGLOG(@"[DG] [%d/%d] lendo %s em 0x%llx (%zu bytes)",
              i + 1, (int)DG_TOTAL, a->nome, (unsigned long long)addr, a->tam);

        BOOL leu = NO;
        @try {
            leu = [TitanoxHook readMemoryAt:addr buffer:atual size:a->tam];
        } @catch (NSException *e) {
            DGLOG(@"[DG] %s: excecao na leitura: %@", a->nome, e.reason);
            leu = NO;
        }

        if (!leu) {
            DGLOG(@"[DG] %s: leitura FALHOU em 0x%llx", a->nome, (unsigned long long)addr);
            continue;
        }

        // Os bytes tem de casar com o stub (IPA patchado) ou com o original
        // (IPA limpo). Qualquer outra coisa = versao diferente do jogo -> nao
        // escrever nada nesse alvo.
        if (memcmp(atual, a->stub, a->tam) == 0) {
            g_valida[i] = YES;
            g_ligada[i] = YES;
            validos++;
            DGLOG(@"[DG] %s: OK (estado inicial LIGADO)", a->nome);
        } else if (memcmp(atual, a->original, a->tam) == 0) {
            g_valida[i] = YES;
            g_ligada[i] = NO;
            validos++;
            DGLOG(@"[DG] %s: OK (estado inicial DESLIGADO)", a->nome);
        } else {
            g_valida[i] = NO;
            DGLOG(@"[DG] %s: bytes DESCONHECIDOS em 0x%llx - alvo desabilitado "
                  @"(versao do jogo diferente?)", a->nome, (unsigned long long)addr);
        }
    }

    DGLOG(@"[DG] alvos validos: %d de %d", validos, (int)DG_TOTAL);
    if (validos == 0) {
        g_erro = @"nenhum alvo validou - versao do jogo diferente do dump";
    }
    DGLOG(@"[DG] inicializar: terminou");
}

+ (BOOL)definir:(DgFeature)f ligada:(BOOL)ligar {
    if (f < 0 || f >= DG_TOTAL) return NO;
    if (!g_valida[f]) {
        DGLOG(@"[DG] %s: ignorado (alvo invalido)", g_alvos[f].nome);
        return NO;
    }
    if (g_base == 0) return NO;
    if (g_ligada[f] == ligar) return YES;   // nada a fazer

    DgAlvo *a = &g_alvos[f];
    mach_vm_address_t addr = (mach_vm_address_t)(g_base + a->rva);
    uint8_t *dados = ligar ? a->stub : a->original;

    // Pagina de codigo e R-X. Para escrever, pedir RW. E AQUI que o iOS pode
    // dizer nao em app sideloaded - por isso o retorno e conferido e logado.
    kern_return_t kr = [TitanoxHook protectMemoryAt:addr
                                               size:a->tam
                                             setMax:NO
                                         protection:(VM_PROT_READ | VM_PROT_WRITE)];
    if (kr != KERN_SUCCESS) {
        DGLOG(@"[DG] %s: protect(RW) falhou kr=%d", a->nome, kr);
        g_erro = [NSString stringWithFormat:@"vm_protect recusado (kr=%d)", kr];
        return NO;
    }

    [TitanoxHook patchMemoryAtAddress:(void *)addr withPatch:dados size:a->tam];

    // Devolver a protecao original. Se falhar nao e fatal, mas fica no log.
    kern_return_t kr2 = [TitanoxHook protectMemoryAt:addr
                                                size:a->tam
                                              setMax:NO
                                          protection:(VM_PROT_READ | VM_PROT_EXECUTE)];
    if (kr2 != KERN_SUCCESS) {
        DGLOG(@"[DG] %s: protect(RX) de volta falhou kr=%d", a->nome, kr2);
    }

    // NAO confiar na escrita: reler e comparar. Se nao bateu, o toggle nao valeu.
    uint8_t conferido[48] = {0};
    if ([TitanoxHook readMemoryAt:addr buffer:conferido size:a->tam] &&
        memcmp(conferido, dados, a->tam) == 0) {
        g_ligada[f] = ligar;
        g_escritaOk = YES;
        DGLOG(@"[DG] %s: agora %s", a->nome, ligar ? "LIGADO" : "DESLIGADO");
        return YES;
    }

    DGLOG(@"[DG] %s: escrita NAO confirmada na releitura", a->nome);
    g_erro = @"escrita em memoria de codigo nao confirmada";
    return NO;
}

+ (NSString *)diagnostico {
    int validos = 0;
    for (int i = 0; i < DG_TOTAL; i++) if (g_valida[i]) validos++;
    return [NSString stringWithFormat:
            @"base 0x%llx | alvos %d/%d | escrita: %@%@",
            (unsigned long long)g_base, validos, (int)DG_TOTAL,
            g_escritaOk ? @"OK" : @"nao testada",
            g_erro ? [@" | " stringByAppendingString:g_erro] : @""];
}

@end
