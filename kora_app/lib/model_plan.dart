// Model stub — planes ahora se manejan como Map<String, dynamic> en PlansProvider
class PlanModel {
  final int id;
  final String titulo;
  PlanModel({required this.id, required this.titulo});
  factory PlanModel.fromApi(Map<String, dynamic> j) =>
      PlanModel(id: j['id'] ?? 0, titulo: j['titulo'] ?? '');
}
