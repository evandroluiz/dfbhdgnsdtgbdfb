   function expande(x)
      // funcao para expandir/contrair texto
      {
        novo = (document.getElementById(x).style.display == 'none') ? 'block' : 'none';
         document.getElementById(x).style.display = novo;
      }