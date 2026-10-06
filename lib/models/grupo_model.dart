import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// Racha recorrente: guarda a configuração padrão usada para gerar
/// automaticamente a próxima ocorrência (Racha) toda semana.
class GrupoModel {
  final String id;
  final String nome;
  final String localPadrao;
  final TipoCampo tipoCampoPadrao;
  final int qtdJogadoresLinhaPadrao;
  final DiaSemana diaSemana;
  final String horario; // formato "HH:mm"
  final String adminId;
  final List<String> membrosFixos; // ids de User
  // Coordenadas capturadas pelo admin ao criar/editar o grupo — nulo pra
  // grupos criados antes dessa feature, que por isso nunca aparecem na aba
  // "Rachas Próximos" (não tem como calcular distância sem elas).
  final GeoPoint? localizacao;
  // Controla se o grupo aparece na busca por proximidade pra qualquer
  // jogador logado, que pode então solicitar entrada (ver SolicitacaoModel).
  final bool abertoParaNovosMembros;
  /// Jogadores autorizados a fazer a chamada nas rodadas deste grupo — os
  /// "caras da planilha". Não é co-administração: eles registram presença e
  /// nada mais, não editam o racha nem aprovam entrada.
  final List<String> auxiliares;

  /// Foto do racha (o campo, a quadra, a turma) em base64, ou nulo.
  ///
  /// Mesma estratégia provisória da foto de perfil: o Firebase Storage
  /// exige o plano pago, então a imagem mora no próprio documento. Por
  /// isso ela é comprimida bem mais que a de perfil antes de chegar aqui
  /// — este documento é lido em toda lista de grupos da tela inicial e da
  /// aba "Rachas Próximos", e cada KB a mais pesa N vezes.
  final String? fotoBase64;

  const GrupoModel({
    required this.id,
    required this.nome,
    required this.localPadrao,
    required this.tipoCampoPadrao,
    required this.qtdJogadoresLinhaPadrao,
    required this.diaSemana,
    required this.horario,
    required this.adminId,
    this.membrosFixos = const [],
    this.localizacao,
    this.abertoParaNovosMembros = false,
    this.auxiliares = const [],
    this.fotoBase64,
  });

  factory GrupoModel.fromMap(String id, Map<String, dynamic> map) {
    return GrupoModel(
      id: id,
      nome: map['nome'] as String,
      localPadrao: map['localPadrao'] as String,
      tipoCampoPadrao: TipoCampo.values.byName(map['tipoCampoPadrao'] as String),
      qtdJogadoresLinhaPadrao: map['qtdJogadoresLinhaPadrao'] as int,
      diaSemana: DiaSemana.values.byName(map['diaSemana'] as String),
      horario: map['horario'] as String,
      adminId: map['adminId'] as String,
      membrosFixos: List<String>.from(map['membrosFixos'] as List? ?? const []),
      localizacao: map['localizacao'] as GeoPoint?,
      abertoParaNovosMembros: map['abertoParaNovosMembros'] as bool? ?? false,
      auxiliares: List<String>.from(map['auxiliares'] as List? ?? const []),
      fotoBase64: map['fotoBase64'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'localPadrao': localPadrao,
      'tipoCampoPadrao': tipoCampoPadrao.name,
      'qtdJogadoresLinhaPadrao': qtdJogadoresLinhaPadrao,
      'diaSemana': diaSemana.name,
      'horario': horario,
      'adminId': adminId,
      'membrosFixos': membrosFixos,
      'localizacao': localizacao,
      'abertoParaNovosMembros': abertoParaNovosMembros,
      'auxiliares': auxiliares,
      'fotoBase64': fotoBase64,
    };
  }

  GrupoModel copyWith({
    String? nome,
    String? localPadrao,
    TipoCampo? tipoCampoPadrao,
    int? qtdJogadoresLinhaPadrao,
    DiaSemana? diaSemana,
    String? horario,
    List<String>? membrosFixos,
    GeoPoint? localizacao,
    bool? abertoParaNovosMembros,
    List<String>? auxiliares,
  }) {
    return GrupoModel(
      id: id,
      nome: nome ?? this.nome,
      localPadrao: localPadrao ?? this.localPadrao,
      tipoCampoPadrao: tipoCampoPadrao ?? this.tipoCampoPadrao,
      qtdJogadoresLinhaPadrao:
          qtdJogadoresLinhaPadrao ?? this.qtdJogadoresLinhaPadrao,
      diaSemana: diaSemana ?? this.diaSemana,
      horario: horario ?? this.horario,
      adminId: adminId,
      membrosFixos: membrosFixos ?? this.membrosFixos,
      localizacao: localizacao ?? this.localizacao,
      abertoParaNovosMembros: abertoParaNovosMembros ?? this.abertoParaNovosMembros,
      auxiliares: auxiliares ?? this.auxiliares,
      fotoBase64: fotoBase64,
    );
  }
}
