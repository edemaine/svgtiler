Border = (props) ->
  <line {...props} stroke="black" stroke-width="5" stroke-linecap="round"/>

(key) ->
  <symbol viewBox="-10 -10 20 20" boundingBox="-12.5 -12.5 25 25">
    {if @neighbor(-1,0).key != key
      <Border x1="-10" y1="-10" x2="-10" y2="10"/>
    }
    {if @neighbor(+1,0).key != key
      <Border x1="10" y1="-10" x2="10" y2="10"/>
    }
    {if @neighbor(0,-1).key != key
      <Border x1="-10" y1="-10" x2="10" y2="-10"/>
    }
    {if @neighbor(0,+1).key != key
      <Border x1="-10" y1="10" x2="10" y2="10"/>
    }
  </symbol>
