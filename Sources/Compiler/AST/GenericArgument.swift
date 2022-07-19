/// The expression of an argument to a generic entity.
public enum GenericArgument: Hashable {

  case value(AnyExprID)

  case type(AnyTypeExprID)

}
